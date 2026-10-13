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

    /// Os países em ordem alfabética pelo NOME mostrado.
    ///
    /// É a lista do seletor do formulário, e sai da MESMA tabela que dá nome ao
    /// país na tela: só se pode escolher um país que o app sabe nomear.
    static let ordenados: [(iso: String, nome: String)] = nomes
        .map { (iso: $0.key, nome: $0.value) }
        .sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }

    /// O nome do país, ou o próprio código quando ele não está na tabela.
    ///
    /// Devolver o código em vez de vazio é de propósito: um país desconhecido
    /// tem de APARECER, para alguém notar e acrescentá-lo. Sumir calado seria
    /// esconder um livro.
    static func nome(_ iso: String) -> String {
        let c = iso.trimmingCharacters(in: .whitespaces).uppercased()
        return nomes[c] ?? c
    }

    static func conhecido(_ iso: String) -> Bool {
        nomes[iso.trimmingCharacters(in: .whitespaces).uppercased()] != nil
    }
}
