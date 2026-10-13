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

    // MARK: - A lista do seletor do formulário
    //
    // O campo de país entrou em 13/10/2026. Até ele, os 280 países da base
    // vinham todos de `bin/semear-pais.py`, de fora do app, e não havia como
    // pôr nem CORRIGIR o país de um livro.

    func testOSeletorOfereceTodoPaisQueOAppSabeNomear() {
        XCTAssertEqual(Paises.ordenados.count, 47)
        for p in Paises.ordenados {
            XCTAssertTrue(Paises.conhecido(p.iso))
            XCTAssertEqual(Paises.nome(p.iso), p.nome)
        }
        XCTAssertEqual(Set(Paises.ordenados.map(\.iso)).count, Paises.ordenados.count)
    }

    // Ordem pelo NOME mostrado, não pelo código: pelo código a lista começaria
    // em AO (Angola). E a inicial acentuada tem de ficar no lugar da LETRA —
    // numa comparação por código de caractere, "Áustria" e "Índia" iriam para
    // o fim da lista, longe de onde alguém as procura. (Em 13/10/2026 era
    // exatamente isso que acontecia no Android, que não tem colação local.)
    func testOrdemPeloNomeIgnorandoAcento() {
        let nomes = Paises.ordenados.map(\.nome)
        XCTAssertEqual(nomes.first, "África do Sul")
        XCTAssertLessThan(nomes.firstIndex(of: "Alemanha")!, nomes.firstIndex(of: "Angola")!)
        XCTAssertEqual(nomes.firstIndex(of: "Áustria"), nomes.firstIndex(of: "Austrália")! + 1)
        XCTAssertLessThan(nomes.firstIndex(of: "Índia")!, nomes.firstIndex(of: "Irã")!)
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
