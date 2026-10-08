import Foundation
import Testing
@testable import Biblioteca_App

/// O comentário dos livros do Kindle traz dois endereços rotulados:
///
///     Ler: https://read.amazon.com/?asin=XXXX | Kindle: kindle://book?...
///
/// Na tela aparece só o rótulo — "Ler | Kindle" —, porque a URL inteira ocupa
/// várias linhas e no Android chegava a empurrar o resto da seção para fora.
@Suite("Rótulo do link")
struct RotuloDoLinkTests {

    @Test("o rótulo escrito antes do endereço é separado do texto comum")
    func separaORotulo() {
        let r = separarRotulo("Ler: ")
        #expect(r?.rotulo == "Ler")
        #expect(r?.prefixo == "")

        let s = separarRotulo(" | Kindle: ")
        #expect(s?.rotulo == "Kindle")
        // O espaco no fim do prefixo e de proposito: e ele que separa o "|"
        // do link na tela.
        #expect(s?.prefixo == " | ")
    }

    @Test("o rótulo para em pontuação de frase")
    func paraNaFrase() {
        // Sem isto, "…funesto. Ler: http…" devolveria meia frase como rótulo e
        // deixaria um pedaço de palavra solto na tela.
        let r = separarRotulo("Noite sem fim, um pressentimento funesto. Ler: ")
        #expect(r?.rotulo == "Ler")
        #expect(r?.prefixo == "Noite sem fim, um pressentimento funesto. ")
    }

    @Test("sem rótulo não inventa um")
    func semRotulo() {
        #expect(separarRotulo("comprei em 2019 ") == nil)
        #expect(separarRotulo("") == nil)
    }
}
