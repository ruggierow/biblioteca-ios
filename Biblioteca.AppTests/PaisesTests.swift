// A tabela por país no celular — não mapa, por decisão do usuário em 12/10/2026:
// "no iPhone e no Android faça por tabela e não por mapa".
import XCTest
@testable import Biblioteca_App

final class PaisesTests: XCTestCase {
    private func livro(_ titulo: String, pais: String = "") -> Livro {
        var l = Livro()
        l.titulo = titulo
        l.pais = pais
        return l
    }

    func testTraduzOCodigo() {
        XCTAssertEqual(Paises.nome("BR"), "Brasil")
        XCTAssertEqual(Paises.nome("jp"), "Japão")
    }

    // Um país fora da tabela tem de APARECER, para alguém notar e acrescentá-lo.
    // Sumir calado seria esconder um livro.
    func testCodigoDesconhecidoApareceComoEleMesmo() {
        XCTAssertEqual(Paises.nome("ZZ"), "ZZ")
        XCTAssertFalse(Paises.conhecido("ZZ"))
    }

    func testFiltroAceitaSoOPaisEscolhido() {
        var f = FiltroPesquisa()
        f.pais = "BR"
        XCTAssertTrue(f.aceita(livro("Daqui", pais: "BR")))
        XCTAssertFalse(f.aceita(livro("De fora", pais: "JP")))
        XCTAssertFalse(f.aceita(livro("Sem pais")))
    }

    func testFiltroIgnoraMaiusculas() {
        var f = FiltroPesquisa()
        f.pais = "BR"
        XCTAssertTrue(f.aceita(livro("x", pais: "br")))
    }

    func testSemPaisEscolhidoNaoFiltra() {
        let f = FiltroPesquisa()
        XCTAssertTrue(f.aceita(livro("x", pais: "JP")))
        XCTAssertTrue(f.aceita(livro("y")))
    }

    func testContaComoFiltroLigadoEApareceNoResumo() {
        var f = FiltroPesquisa()
        f.pais = "PT"
        XCTAssertTrue(f.ativo)
        XCTAssertEqual(f.quantosLigados, 1)
        XCTAssertTrue(f.resumo(nomeDoGrupo: { _ in "" }).contains("Portugal"))
    }

    func testLimparDesligaOPais() {
        var f = FiltroPesquisa()
        f.pais = "PT"
        f.limpar()
        XCTAssertEqual(f.pais, "")
        XCTAssertFalse(f.ativo)
    }
}
