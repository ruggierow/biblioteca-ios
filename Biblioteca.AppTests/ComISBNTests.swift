// O ISBN entra no campo de comentarios, nao numa 9a coluna: o leitor do
// motor-web descarta linha com 9 campos e o livro sumiria no Mac e no Windows.
// Os mesmos casos estao provados no motor-web e no Android.
import XCTest
@testable import Biblioteca_App

final class ComISBNTests: XCTestCase {
    func testCampoVazioRecebeSoAMarca() {
        XCTAssertEqual(comISBN("", "978-85-359-0277-8"), "ISBN: 9788535902778")
    }
    func testAnexaPreservandoOQueJaEstavaLa() {
        XCTAssertEqual(comISBN("Editora: Companhia das Letras", "9788535902778"),
                       "Editora: Companhia das Letras | ISBN: 9788535902778")
    }
    func testRelerOMesmoNaoDuplica() {
        XCTAssertEqual(comISBN("ISBN: 9788535902778", "9788535902778"), "ISBN: 9788535902778")
    }
    func testRelerComOutroSubstitui() {
        XCTAssertEqual(comISBN("Editora: X | ISBN: 1111111111", "9788535902778"),
                       "Editora: X | ISBN: 9788535902778")
    }
    func testISBN10TerminadoEmX() {
        XCTAssertEqual(comISBN("Ler: https://a | Kindle: kindle://b", "85-359-0277-x"),
                       "Ler: https://a | Kindle: kindle://b | ISBN: 853590277X")
    }
    func testSemISBNNaoToca() {
        XCTAssertEqual(comISBN("Editora: X", ""), "Editora: X")
    }
}
