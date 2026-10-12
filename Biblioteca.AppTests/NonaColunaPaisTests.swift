// A nona coluna (pais) entra em DUAS etapas, e esta versao e a primeira: o
// aplicativo aprende a ler e a DEVOLVER o campo, sem ainda mostrar nada.
//
// Por que a ordem importa: ate a 1.9.13 o motor-web descartava EM SILENCIO a
// linha com 9 colunas. Como o Mac salva sozinho, o dado entrando antes faria a
// biblioteca abrir vazia e o vazio ser gravado por cima.
import XCTest
@testable import Biblioteca_App

final class NonaColunaPaisTests: XCTestCase {
    private func store(_ texto: String) -> BibliotecaStore {
        let s = BibliotecaStore()
        s.livros = s.parsear(texto)
        return s
    }

    func testLinhaDe9CamposTrazOPais() {
        let l = store("Com Pais\tAutor\tTema\t2020\t0\t\tEstante\t0\tBR").livros
        XCTAssertEqual(l.count, 1)
        XCTAssertEqual(l[0].pais, "BR")
    }

    func testLinhaDe8CamposContinuaValendo() {
        let l = store("Sem Pais\tAutor\tTema\t2020\t0\t\tEstante\t0").livros
        XCTAssertEqual(l.count, 1)
        XCTAssertEqual(l[0].pais, "")
    }

    func testIdaEVoltaPreservaOPais() {
        let s = store("Ida\tAutor\tTema\t2020\t0\tnota\tEstante\t0\tJP")
        let devolta = s.parsear(s.serializar())
        XCTAssertEqual(devolta[0].pais, "JP")
        XCTAssertEqual(s.serializar(), "Ida\tAutor\tTema\t2020\t0\tnota\tEstante\t0\tJP")
    }

    func testSemPaisSaiComOitoColunas() {
        let s = store("Sem Pais\tAutor\tTema\t2020\t0\t\tEstante\t0")
        XCTAssertEqual(s.serializar().components(separatedBy: "\t").count, 8)
    }

    func testCodigoGuardadoEmMaiusculas() {
        XCTAssertEqual(store("X\tA\tT\t2020\t0\t\tE\t0\tbr").livros[0].pais, "BR")
    }

    func testBaseMistaNaoPerdeLivro() {
        let s = store("Com\tA\tT\t2020\t0\t\tE\t0\tBR\nSem\tA\tT\t2021\t0\t\tE\t0")
        XCTAssertEqual(s.livros.count, 2)
        let devolta = s.parsear(s.serializar())
        XCTAssertEqual(devolta.map { $0.pais }, ["BR", ""])
    }
}
