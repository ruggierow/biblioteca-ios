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
}
