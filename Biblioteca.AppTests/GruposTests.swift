import Foundation
import Testing
@testable import Biblioteca_App

/// Testes da coluna 8 do arquivo — a participação em grupos de literatura.
///
/// A interface web guarda ali uma LISTA de grupos separada por ponto e vírgula
/// ("1;3"), com nomes que o usuário gerencia. Este motor só distingue
/// participar de não participar, mas não pode achatar o que não entende: até
/// 13/09/2026 ele lia qualquer coisa diferente de "1" como falso e regravava
/// "0", apagando em silêncio a participação nos demais grupos.
@Suite("Grupos de literatura")
struct GruposTests {

    @Test("qualquer grupo positivo conta como participação")
    func participacao() {
        #expect(Livro.participaDeGrupo("1"))
        #expect(Livro.participaDeGrupo("2"))
        #expect(Livro.participaDeGrupo("1;3"))
        #expect(!Livro.participaDeGrupo("0"))
        #expect(!Livro.participaDeGrupo(""))
    }

    @Test("manter a participação não reescreve a lista")
    func manterNaoReescreve() {
        var l = Livro()
        l.grupos = "1;3"
        l.grupoLiteratura = true
        #expect(l.grupos == "1;3")
    }

    @Test("desligar zera, religar volta com o grupo 1")
    func desligarEReligar() {
        var l = Livro()
        l.grupos = "1;3"
        l.grupoLiteratura = false
        #expect(l.grupos == "0")
        l.grupoLiteratura = true
        #expect(l.grupos == "1")
    }

    @Test("a lista sobrevive a ler e regravar o arquivo")
    func idaEVolta() {
        let store = BibliotecaStore()
        let livros = store.parsear("T\tA\tX\t2000\t0\t\t\t1;3")
        #expect(livros.count == 1)
        #expect(livros[0].grupos == "1;3")
        #expect(livros[0].grupoLiteratura)

        store.livros = livros
        #expect(store.serializar().components(separatedBy: "\t").last == "1;3")
    }

    @Test("listaGrupos le e escreve a coluna")
    func listaIdaEVolta() {
        var l = Livro()
        l.grupos = "1;3"
        #expect(l.listaGrupos == [1, 3])
        l.listaGrupos = [2, 5]
        #expect(l.grupos == "2;5")
        l.listaGrupos = []
        #expect(l.grupos == "0")
        #expect(!l.grupoLiteratura)
    }

    @Test("grupo sem nome conhecido vira \"Grupo N\"")
    func nomeDesconhecido() {
        #expect(GruposStore.shared.nome(97) == "Grupo 97")
    }

    @Test("o seletor oferece tambem os grupos que so aparecem nos livros")
    func oferecidos() {
        var l = Livro()
        l.grupos = "1;7"
        let ids = GruposStore.shared.oferecidos(nosLivros: [l]).map(\.id)
        #expect(ids.contains(1))
        #expect(ids.contains(7))
        #expect(ids == ids.sorted())
    }
}

@Suite("Filtro da pesquisa")
struct FiltroPesquisaTests {

    private func livro(emprestado: Bool = false, grupos: String = "0") -> Livro {
        var l = Livro()
        l.titulo = "T"
        l.emprestado = emprestado
        l.grupos = grupos
        return l
    }

    @Test("sem filtro nenhum, tudo passa")
    func vazio() {
        let f = FiltroPesquisa()
        #expect(!f.ativo)
        #expect(f.aceita(livro()))
        #expect(f.aceita(livro(emprestado: true, grupos: "2")))
    }

    @Test("status separa emprestados de disponiveis")
    func status() {
        var f = FiltroPesquisa()
        f.status = .emprestados
        #expect(f.ativo)
        #expect(f.aceita(livro(emprestado: true)))
        #expect(!f.aceita(livro(emprestado: false)))

        f.status = .disponiveis
        #expect(f.aceita(livro(emprestado: false)))
        #expect(!f.aceita(livro(emprestado: true)))
    }

    @Test("grupo especifico nao aceita quem esta so em outro")
    func grupoEspecifico() {
        var f = FiltroPesquisa()
        f.grupo = .especifico(3)
        #expect(f.aceita(livro(grupos: "1;3")))
        #expect(!f.aceita(livro(grupos: "1")))
        #expect(!f.aceita(livro(grupos: "0")))

        f.grupo = .qualquer
        #expect(f.aceita(livro(grupos: "2")))
        #expect(!f.aceita(livro(grupos: "0")))
    }

    @Test("limpar desliga tudo")
    func limpar() {
        var f = FiltroPesquisa()
        f.texto = "x"; f.status = .emprestados; f.grupo = .qualquer; f.comFoto = true
        #expect(f.quantosLigados == 3)
        f.limpar()
        #expect(!f.ativo)
        #expect(f.quantosLigados == 0)
        #expect(f.texto.isEmpty)
    }

    @Test("o resumo nomeia o grupo escolhido")
    func resumo() {
        var f = FiltroPesquisa()
        f.status = .emprestados
        f.grupo = .especifico(2)
        f.comFoto = true
        let texto = f.resumo(nomeDoGrupo: { "Clube \($0)" })
        #expect(texto == "Emprestados · Clube 2 · Com foto")
        #expect(FiltroPesquisa().resumo(nomeDoGrupo: { _ in "x" }).isEmpty)
    }
}
