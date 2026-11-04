import Foundation

/// Os nomes dos países, a partir do código ISO de duas letras da coluna 9.
///
/// A coluna guarda o código, não o nome: acento e grafia divergem entre as
/// quatro plataformas, e o mapa do Mac precisa casar região com valor. O nome
/// só existe na hora de mostrar.
///
/// A tabela é a mesma do `bin/semear-pais.py`, do motor-web e do Android. Um
/// código que não esteja aqui aparece como ele mesmo — nunca some.
enum Paises {
    private static let nomes: [String: String] = [
        "BR": "Brasil", "AR": "Argentina", "CL": "Chile", "CO": "Colômbia",
        "PE": "Peru", "UY": "Uruguai", "US": "Estados Unidos", "CA": "Canadá",
        "MX": "México", "CU": "Cuba", "PT": "Portugal", "ES": "Espanha",
        "FR": "França", "GB": "Reino Unido", "IE": "Irlanda", "DE": "Alemanha",
        "IT": "Itália", "CH": "Suíça", "AT": "Áustria", "BE": "Bélgica",
        "NL": "Holanda", "DK": "Dinamarca", "SE": "Suécia", "NO": "Noruega",
        "PL": "Polônia", "CZ": "Tchéquia", "HU": "Hungria", "GR": "Grécia",
        "BY": "Bielorrússia", "RU": "Rússia", "TR": "Turquia", "IL": "Israel",
        "PS": "Palestina", "LB": "Líbano", "IR": "Irã", "IN": "Índia",
        "CN": "China", "KR": "Coreia do Sul", "JP": "Japão", "EG": "Egito",
        "SN": "Senegal", "NG": "Nigéria", "AO": "Angola", "RW": "Ruanda",
        "MZ": "Moçambique", "ZA": "África do Sul", "AU": "Austrália",
    ]

    /// Os mesmos 47 códigos em inglês, numa tabela SEPARADA.
    ///
    /// Separada, e não um segundo valor na tabela de cima, porque
    /// `bin/conferir-paises.py` lê `nomes` por recorte de texto e compara nome
    /// por nome com as outras três plataformas. Mexer na forma dela quebraria
    /// o portão. Os nomes vêm do `PAISES_EN` do motor-web, copiados de lá.
    private static let nomesIngles: [String: String] = [
        "BR": "Brazil", "AR": "Argentina", "CL": "Chile", "CO": "Colombia",
        "PE": "Peru", "UY": "Uruguay", "US": "United States", "CA": "Canada",
        "MX": "Mexico", "CU": "Cuba", "PT": "Portugal", "ES": "Spain",
        "FR": "France", "GB": "United Kingdom", "IE": "Ireland",
        "DE": "Germany", "IT": "Italy", "CH": "Switzerland", "AT": "Austria",
        "BE": "Belgium", "NL": "Netherlands", "DK": "Denmark", "SE": "Sweden",
        "NO": "Norway", "PL": "Poland", "CZ": "Czechia", "HU": "Hungary",
        "GR": "Greece", "BY": "Belarus", "RU": "Russia", "TR": "Turkey",
        "IL": "Israel", "PS": "Palestine", "LB": "Lebanon", "IR": "Iran",
        "IN": "India", "CN": "China", "KR": "South Korea", "JP": "Japan",
        "EG": "Egypt", "SN": "Senegal", "NG": "Nigeria", "AO": "Angola",
        "RW": "Rwanda", "MZ": "Mozambique", "ZA": "South Africa",
        "AU": "Australia",
    ]

    /// Os códigos de cada tabela, para o portão da tradução.
    ///
    /// Expostos porque `nome()` NÃO delata a falta: sem o código na tabela
    /// inglesa ele cai no português e devolve "Moçambique" para `MZ`, que não
    /// é igual ao código — um teste que comparasse com o ISO passaria verde.
    static var codigos: Set<String> { Set(nomes.keys) }
    static var codigosIngles: Set<String> { Set(nomesIngles.keys) }

    /// Os países em ordem alfabética pelo NOME mostrado.
    ///
    /// É a lista do seletor do formulário, e sai da MESMA tabela que dá nome ao
    /// país na tela: só se pode escolher um país que o app sabe nomear.
    static var ordenados: [(iso: String, nome: String)] { nomes
        .map { (iso: $0.key, nome: Self.nome($0.key)) }
        .sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending } }

    /// O nome do país, ou o próprio código quando ele não está na tabela.
    ///
    /// Devolver o código em vez de vazio é de propósito: um país desconhecido
    /// tem de APARECER, para alguém notar e acrescentá-lo. Sumir calado seria
    /// esconder um livro.
    static func nome(_ iso: String) -> String {
        let c = iso.trimmingCharacters(in: .whitespaces).uppercased()
        if idiomaAtual == "en", let emIngles = nomesIngles[c] { return emIngles }
        return nomes[c] ?? c
    }

    static func conhecido(_ iso: String) -> Bool {
        nomes[iso.trimmingCharacters(in: .whitespaces).uppercased()] != nil
    }
}
