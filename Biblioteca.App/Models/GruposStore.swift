import Combine
import Foundation

/// Um grupo de literatura: o numero que aparece na coluna 8 do arquivo e o
/// nome que o usuario deu a ele.
struct Grupo: Identifiable, Equatable {
    let id: Int
    let nome: String
}

/// Os NOMES dos grupos nao cabem no `biblioteca.txt`, que guarda so os numeros
/// ("1;3"). Eles vivem num `grupos.json` ao lado do arquivo, escrito pelo Mac.
///
/// Quem vincula uma PASTA (Mac e iPhone) le esse arquivo sozinho. Quem vincula
/// documentos avulsos (Windows no Chrome, Android pelo SAF) ainda nao o
/// alcanca — nesses casos os grupos aparecem como "Grupo 1", "Grupo 2", e o
/// filtro funciona igual. So o rotulo muda.
final class GruposStore: ObservableObject {
    static let shared = GruposStore()

    static let padrao = Grupo(id: 1, nome: "Grupo de Literatura")

    @Published private(set) var grupos: [Grupo] = [padrao]

    /// Le `grupos.json` da pasta vinculada. Silencioso de proposito: a ausencia
    /// do arquivo e o caso normal em quem nunca renomeou nada.
    func carregar(de pasta: URL?) {
        guard let pasta else { return }
        let url = pasta.appendingPathComponent("grupos.json")
        guard let dados = try? Data(contentsOf: url),
              let raiz = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let itens = raiz["grupos"] as? [[String: Any]]
        else { return }

        let lidos: [Grupo] = itens.compactMap { item in
            guard let id = item["id"] as? Int, id > 0,
                  let nome = (item["nome"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !nome.isEmpty
            else { return nil }
            return Grupo(id: id, nome: nome)
        }
        guard !lidos.isEmpty else { return }
        grupos = lidos.sorted { $0.id < $1.id }
    }

    /// O nome do grupo, ou "Grupo N" quando o `grupos.json` nao o descreve.
    func nome(_ id: Int) -> String {
        grupos.first { $0.id == id }?.nome ?? "Grupo \(id)"
    }

    /// Os grupos que o seletor deve oferecer: os conhecidos, mais os que
    /// aparecem nos livros sem estar no `grupos.json`.
    func oferecidos(nosLivros livros: [Livro]) -> [Grupo] {
        let conhecidos = Set(grupos.map(\.id))
        let extras = Set(livros.flatMap(\.listaGrupos)).subtracting(conhecidos)
        return (grupos + extras.map { Grupo(id: $0, nome: "Grupo \($0)") })
            .sorted { $0.id < $1.id }
    }
}
