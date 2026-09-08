import Foundation

struct Livro: Identifiable {
    var id = UUID()
    var titulo: String = ""
    var autores: [String] = [""]
    var temas: [String] = [""]
    var ano: String = ""
    var emprestado: Bool = false
    var comentarios: String = ""
    var local: String = ""
    var grupoLiteratura: Bool = false

    /// Chave determinística derivada de título + autores.
    /// Usa o mesmo hash FNV-1a da interface web, garantindo que o mesmo livro
    /// receba sempre o mesmo identificador — estável mesmo após reimportar o TSV.
    var fotoId: String {
        let tNorm = titulo
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let aNorm = autores
            .map {
                $0.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .sorted()
        let chave = ([tNorm] + aNorm).joined(separator: "\0")

        var h1: UInt32 = 2_166_136_261
        var h2: UInt32 = 2_246_822_519
        for (i, scalar) in chave.unicodeScalars.enumerated() {
            let c = scalar.value
            h1 = (h1 ^ c) &* 16_777_619
            h2 = (h2 ^ (c &+ UInt32(i) &+ 1)) &* 16_777_619
        }
        return String(h1, radix: 36) + String(h2, radix: 36)
    }
}
