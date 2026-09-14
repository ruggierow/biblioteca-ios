import Foundation

enum FiltroStatus: String, CaseIterable, Identifiable {
    case todos, disponiveis, emprestados
    var id: String { rawValue }
    var rotulo: String {
        switch self {
        case .todos:       return "Todos"
        case .disponiveis: return "Disponíveis"
        case .emprestados: return "Emprestados"
        }
    }
}

enum FiltroGrupo: Hashable {
    case todos
    case qualquer
    case especifico(Int)
}

/// Os filtros da pesquisa, espelhando os do Mac e do Windows.
///
/// A diferenca deliberada: la sao quatro caixas de texto (titulo, autor, tema,
/// local); aqui e uma caixa so, que procura nos quatro mais o ano. Quatro
/// caixas lado a lado e idioma de tela grande.
struct FiltroPesquisa {
    var texto: String = ""
    var status: FiltroStatus = .todos
    var grupo: FiltroGrupo = .todos
    var comFoto: Bool = false

    var ativo: Bool {
        !texto.trimmingCharacters(in: .whitespaces).isEmpty
            || status != .todos
            || grupo != .todos
            || comFoto
    }

    /// Quantos filtros estao ligados — vira o numerinho ao lado do botao.
    var quantosLigados: Int {
        var n = 0
        if status != .todos { n += 1 }
        if grupo != .todos { n += 1 }
        if comFoto { n += 1 }
        return n
    }

    mutating func limpar() {
        self = FiltroPesquisa()
    }

    /// A descricao dos filtros ligados, para a linha de resumo.
    func resumo(nomeDoGrupo: (Int) -> String) -> String {
        var partes: [String] = []
        if status != .todos { partes.append(status.rotulo) }
        switch grupo {
        case .todos: break
        case .qualquer: partes.append("Qualquer grupo")
        case .especifico(let id): partes.append(nomeDoGrupo(id))
        }
        if comFoto { partes.append("Com foto") }
        return partes.joined(separator: " · ")
    }

    func aceita(_ livro: Livro) -> Bool {
        switch status {
        case .todos: break
        case .disponiveis: if livro.emprestado { return false }
        case .emprestados: if !livro.emprestado { return false }
        }
        switch grupo {
        case .todos: break
        case .qualquer: if !livro.grupoLiteratura { return false }
        case .especifico(let id): if !livro.listaGrupos.contains(id) { return false }
        }
        return true
    }
}
