import Foundation

struct LivroISBN {
    var titulo: String
    var autores: [String]
    var temas: [String]
    var ano: String
    var comentarios: String = ""
}

enum ISBNError: Error {
    case invalido
}

class ISBNService {

    static func buscar(isbn: String) async throws -> LivroISBN? {
        let limpo = isbn.replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: " ", with: "")
        guard (limpo.count == 10 || limpo.count == 13),
              limpo.allSatisfy({ $0.isNumber }) else {
            throw ISBNError.invalido
        }

        if let resultado = try? await brasilAPI(isbn: limpo) { return resultado }
        if let resultado = try? await googleBooks(isbn: limpo) { return resultado }
        return try await openLibrary(isbn: limpo)
    }

    private static func extrairAno(_ str: String) -> String {
        guard let range = str.range(of: #"\d{4}"#, options: .regularExpression) else { return "" }
        return String(str[range])
    }

    private static func brasilAPI(isbn: String) async throws -> LivroISBN? {
        guard let url = URL(string: "https://brasilapi.com.br/api/isbn/v1/\(isbn)") else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let titulo = json["title"] as? String,
              !titulo.isEmpty else { return nil }

        let autores = json["authors"] as? [String] ?? []
        let temas = Array((json["subjects"] as? [String] ?? []).prefix(3))
        let ano = stringValue(json["year"])
        var extras: [String] = []
        if let subtitulo = json["subtitle"] as? String, !subtitulo.isEmpty {
            extras.append(subtitulo)
        }
        if let editora = json["publisher"] as? String, !editora.isEmpty {
            extras.append("Editora: \(editora)")
        }

        return LivroISBN(
            titulo: titulo,
            autores: autores,
            temas: temas,
            ano: ano,
            comentarios: extras.joined(separator: " | ")
        )
    }

    private static func googleBooks(isbn: String) async throws -> LivroISBN? {
        guard let url = URL(string: "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)") else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]],
              let info = items.first?["volumeInfo"] as? [String: Any],
              let titulo = info["title"] as? String,
              !titulo.isEmpty else { return nil }

        let autores = info["authors"] as? [String] ?? []
        let temas = Array((info["categories"] as? [String] ?? []).prefix(3))
        let ano = (info["publishedDate"] as? String).map { extrairAno($0) } ?? ""
        let comentarios = (info["publisher"] as? String).map { "Editora: \($0)" } ?? ""
        return LivroISBN(titulo: titulo, autores: autores, temas: temas, ano: ano, comentarios: comentarios)
    }

    private static func openLibrary(isbn: String) async throws -> LivroISBN? {
        guard let url = URL(string: "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data") else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let livro = json["ISBN:\(isbn)"] as? [String: Any],
              let titulo = livro["title"] as? String,
              !titulo.isEmpty else { return nil }

        let autores = (livro["authors"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let temas = Array(((livro["subjects"] as? [[String: Any]])?.prefix(3).compactMap { $0["name"] as? String }) ?? [])
        let ano = (livro["publish_date"] as? String).map { extrairAno($0) } ?? ""
        let editoras = (livro["publishers"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let comentarios = editoras.isEmpty ? "" : "Editora: \(editoras.joined(separator: ", "))"
        return LivroISBN(titulo: titulo, autores: autores, temas: temas, ano: ano, comentarios: comentarios)
    }

    private static func stringValue(_ value: Any?) -> String {
        if let string = value as? String { return string }
        if let int = value as? Int { return String(int) }
        if let double = value as? Double { return String(Int(double)) }
        return ""
    }
}
