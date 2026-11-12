import XCTest

/// O portão que olha a TELA, e que os testes unitários não conseguem dar.
///
/// POR QUE ELE PRECISA EXISTIR: um rótulo que ficou em português no meio da
/// tela em inglês não quebra teste nenhum de dicionário — a chave existe, a
/// tradução existe, só ninguém a chamou naquele ponto. Medi isso: devolvi
/// `"Escanear livro"` literal ao ContentView e os 65 testes unitários
/// passaram verdes. Só olhando a tela aparece.
///
/// COMO O IDIOMA É FIXADO, sem nenhuma gambiarra no app: `-biblioteca-idioma`
/// como argumento de lançamento entra no domínio de argumentos do
/// `UserDefaults`, que é exatamente de onde `Idioma.carregar()` lê. O app não
/// sabe que está em teste, e o valor não fica gravado depois.
final class IdiomaNaTelaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func abrir(idioma: String) -> XCUIApplication {
        let app = XCUIApplication()
        // O MESMO truque do idioma, agora para o vinculo: um valor no dominio
        // de argumentos vence o que esta gravado. `bibliotecaPastaBookmark`
        // e lido com `data(forKey:)`, e um argumento chega como String — que
        // nao e Data, entao a leitura devolve nil e o app abre como se nunca
        // tivesse vinculado pasta nenhuma.
        //
        // Sem isto o teste depende do ESTADO DO APARELHO: ele afirma "No file
        // linked", e qualquer simulador onde alguem ja vinculou uma pasta o
        // reprova. Aconteceu duas vezes comigo, em 07/11 e em 12/11, nas duas
        // por resíduo das minhas proprias medicoes.
        app.launchArguments = ["-biblioteca-idioma", idioma,
                               "-bibliotecaPastaBookmark", ""]
        app.launch()
        return app
    }

    func testAbreEmInglesENadaDePortuguesSobra() {
        let app = abrir(idioma: "en")
        XCTAssertTrue(app.staticTexts["Scan a book"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Add a book"].exists)
        XCTAssertTrue(app.staticTexts["Choose folder"].exists)
        XCTAssertTrue(app.staticTexts["Sync"].exists)
        XCTAssertTrue(app.staticTexts["No file linked"].exists)

        // O contrário importa tanto quanto: é este lado que pega o rótulo
        // esquecido, e é o que faltava quando eu medi o furo.
        XCTAssertFalse(app.staticTexts["Escanear livro"].exists)
        XCTAssertFalse(app.staticTexts["Cadastro"].exists)
        XCTAssertFalse(app.staticTexts["Selecionar pasta"].exists)
        XCTAssertFalse(app.staticTexts["Sincronização"].exists)
        XCTAssertFalse(app.staticTexts["Nenhum arquivo vinculado"].exists)
    }

    func testAbreEmPortuguesENadaDeInglesSobra() {
        let app = abrir(idioma: "pt")
        XCTAssertTrue(app.staticTexts["Escanear livro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cadastro"].exists)
        XCTAssertTrue(app.staticTexts["Selecionar pasta"].exists)
        XCTAssertTrue(app.staticTexts["Sincronização"].exists)

        XCTAssertFalse(app.staticTexts["Scan a book"].exists)
        XCTAssertFalse(app.staticTexts["Add a book"].exists)
        XCTAssertFalse(app.staticTexts["Choose folder"].exists)
        XCTAssertFalse(app.staticTexts["Sync"].exists)
    }

    /// Trocar no seletor tem de REDESENHAR a tela, não só o rótulo do seletor.
    ///
    /// No app Android o mesmo defeito existiu e a suíte ficou verde: o widget
    /// constante era canonizado e o Flutter pulava a subárvore. No SwiftUI o
    /// risco é gêmeo — só é redesenhada a `View` que DECLARA o que mudou, e
    /// nenhuma tela declara o idioma. É o `.id(idioma.atual)` que resolve, e
    /// é este teste que o guarda.
    func testTrocarNoSeletorRedesenhaATela() {
        let app = abrir(idioma: "pt")
        XCTAssertTrue(app.staticTexts["Escanear livro"].waitForExistence(timeout: 10))

        app.buttons["Idioma / Language"].tap()
        app.buttons["English"].tap()

        XCTAssertTrue(app.staticTexts["Scan a book"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Escanear livro"].exists)
    }
}
