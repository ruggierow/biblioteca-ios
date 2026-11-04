import Foundation
import Testing
@testable import Biblioteca_App

/// Os portões da tradução, espelhando o `IdiomaTests` do Android e o
/// `10-idioma.spec.js` do motor-web.
///
/// O que eles guardam não é a redação — é a FALTA. Uma chave esquecida numa
/// das tabelas não quebra nada: o `t()` cai no português e a tela fica meio
/// traduzida, calada. Só um portão vê isso.
///
/// Nenhum teste daqui troca o idioma globalmente: `comIdioma` usa um valor de
/// TAREFA, isolado. A primeira versão trocava a variável global e derrubou 6
/// testes alheios, que rodam em paralelo no mesmo processo — ver
/// `idiomaDaTarefa` em Idioma.swift.
@Suite("Idioma")
struct IdiomaTests {
    private func comIdioma(_ id: String, _ corpo: () -> Void) {
        comIdiomaNoTeste(id, corpo)
    }

    // MARK: - o dicionário

    @Test("as duas tabelas existem e não estão vazias")
    func tabelasExistem() {
        // Zero chave lida é FALHA, não sucesso: um portão que não olha passa
        // verde.
        #expect(TEXTOS["pt"]!.count > 100)
        #expect(TEXTOS["en"]!.count == TEXTOS["pt"]!.count)
    }

    @Test("nenhuma meia-tradução: as duas tabelas têm as MESMAS chaves")
    func mesmasChaves() {
        let pt = Set(TEXTOS["pt"]!.keys)
        let en = Set(TEXTOS["en"]!.keys)
        #expect(pt.subtracting(en).isEmpty, "chave só em português")
        #expect(en.subtracting(pt).isEmpty, "chave só em inglês")
    }

    @Test("nenhum texto vazio")
    func nenhumVazio() {
        for (_, tabela) in TEXTOS {
            for (chave, texto) in tabela {
                #expect(!texto.trimmingCharacters(in: .whitespaces).isEmpty,
                        "\(chave)")
            }
        }
    }

    @Test("os marcadores de valor são os mesmos nos dois idiomas")
    func mesmosMarcadores() {
        // Se o inglês perde um ${0}, o valor não aparece na tela e ninguém vê:
        // a frase continua lendo bem, só sem o número.
        func marcas(_ s: String) -> Set<String> {
            let re = try! NSRegularExpression(pattern: #"\$\{(\d+)\}"#)
            let ns = s as NSString
            return Set(re.matches(in: s, range: NSRange(location: 0, length: ns.length))
                .map { ns.substring(with: $0.range(at: 1)) })
        }
        for (chave, emPt) in TEXTOS["pt"]! {
            #expect(marcas(TEXTOS["en"]![chave]!) == marcas(emPt), "\(chave)")
        }
    }

    @Test("só estas chaves são iguais nos dois idiomas")
    func apenasEstasIguais() {
        // Igualdade quase sempre é tradução esquecida. As legítimas entram
        // aqui uma a uma, e qualquer outra reprova.
        let iguais = TEXTOS["pt"]!
            .filter { TEXTOS["en"]![$0.key] == $0.value }
            .keys.sorted()
        #expect(iguais == ["extras", "idiomaDica", "status"])
    }

    // MARK: - a escolha do idioma

    @Test("português só quando o aparelho está em português")
    func regraDoAparelho() {
        #expect(idiomaDoAparelho("pt-BR") == "pt")
        #expect(idiomaDoAparelho("pt-PT") == "pt")
        #expect(idiomaDoAparelho("PT") == "pt")
        #expect(idiomaDoAparelho("pt") == "pt")
        #expect(idiomaDoAparelho("en-US") == "en")
        #expect(idiomaDoAparelho("es") == "en")
        #expect(idiomaDoAparelho("fr-CA") == "en")
    }

    @Test("o português é o fallback, mesmo com idioma desconhecido")
    func portuguesEhOFallback() {
        // NÃO se afirma aqui que o padrão é português: no iOS os testes são
        // hospedados pelo app, que roda `carregar()` e segue o APARELHO. O
        // que vale sempre é a queda para a língua-fonte.
        comIdiomaNoTeste("xx") {
            #expect(t("salvar") == "Salvar")
        }
    }

    @Test("chave desconhecida volta como ela mesma, não vazia")
    func chaveDesconhecida() {
        #expect(t("istoNaoExiste") == "istoNaoExiste")
    }

    @Test("t() troca os valores na ordem")
    func trocaOsValores() {
        comIdioma("pt") { #expect(t("grupoNumero", [7]) == "Grupo 7") }
        comIdioma("en") { #expect(t("grupoNumero", [7]) == "Group 7") }
    }

    @Test("valor que falta sai vazio, nunca como ${n} na tela")
    func valorQueFalta() {
        comIdioma("pt") { #expect(t("grupoNumero") == "Grupo ") }
    }

    // MARK: - os países

    @Test("a tabela em inglês tem exatamente os mesmos códigos ISO")
    func mesmosCodigos() {
        // Comparar os CONJUNTOS, e não o que `nome()` devolve: `nome()` cai no
        // português quando falta o inglês, e devolve "Moçambique" para `MZ` —
        // um teste que comparasse com o código ISO passaria verde. Medi isso
        // no Android: a primeira versão deste portão era cega.
        #expect(Paises.codigos.count == 47)
        #expect(Paises.codigosIngles == Paises.codigos)
    }

    @Test("só estes países se escrevem igual nos dois idiomas")
    func paisesIguais() {
        var iguais: [String] = []
        for c in Paises.codigos {
            var pt = ""
            comIdioma("pt") { pt = Paises.nome(c) }
            comIdioma("en") { if Paises.nome(c) == pt { iguais.append(c) } }
        }
        #expect(iguais.sorted() == ["AO", "AR", "CL", "CN", "CU",
                                    "IL", "PE", "PT", "SN"])
    }

    @Test("nome() segue o idioma em vigor")
    func nomeSegueOIdioma() {
        comIdioma("pt") {
            #expect(Paises.nome("BR") == "Brasil")
            #expect(Paises.nome("ZA") == "África do Sul")
        }
        comIdioma("en") {
            #expect(Paises.nome("BR") == "Brazil")
            #expect(Paises.nome("ZA") == "South Africa")
        }
    }

    @Test("o seletor do formulário também segue o idioma")
    func ordenadosSegueOIdioma() {
        // `ordenados` era `static let`, avaliado UMA vez: guardaria a lista em
        // português para sempre. Virou `static var` computada por isso.
        comIdioma("pt") {
            #expect(Paises.ordenados.contains { $0.nome == "Alemanha" })
        }
        comIdioma("en") {
            #expect(Paises.ordenados.contains { $0.nome == "Germany" })
            #expect(!Paises.ordenados.contains { $0.nome == "Alemanha" })
        }
    }

    @Test("código fora da tabela continua aparecendo, nos dois idiomas")
    func codigoDesconhecido() {
        // Sumir calado esconderia um livro.
        comIdioma("pt") { #expect(Paises.nome("XX") == "XX") }
        comIdioma("en") { #expect(Paises.nome("XX") == "XX") }
    }

    // MARK: - os rótulos resolvidos na hora

    @Test("o status do filtro acompanha o idioma")
    func statusAcompanha() {
        comIdioma("pt") { #expect(FiltroStatus.emprestados.rotulo == "Emprestados") }
        comIdioma("en") { #expect(FiltroStatus.emprestados.rotulo == "On loan") }
    }

    @Test("o resumo do filtro acompanha o idioma")
    func resumoAcompanha() {
        var f = FiltroPesquisa()
        f.status = .emprestados
        f.comFoto = true
        comIdioma("pt") {
            #expect(f.resumo(nomeDoGrupo: { _ in "x" }) == "Emprestados · Com foto")
        }
        comIdioma("en") {
            #expect(f.resumo(nomeDoGrupo: { _ in "x" }) == "On loan · With photo")
        }
    }

    @Test("o nome do grupo padrão acompanha o idioma")
    func grupoAcompanha() {
        // Ele mora numa CONSTANTE (`static let padrao`), que em Swift é
        // avaliada uma única vez: guardar o texto congelaria a língua do
        // primeiro acesso. Por isso a constante guarda a CHAVE.
        comIdioma("pt") {
            #expect(GruposStore.shared.nome(1) == "Grupo de Literatura")
            #expect(GruposStore.shared.nome(97) == "Grupo 97")
        }
        comIdioma("en") {
            #expect(GruposStore.shared.nome(1) == "Reading Group")
            #expect(GruposStore.shared.nome(97) == "Group 97")
        }
    }
}
