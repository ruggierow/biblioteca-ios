import Foundation

/// Registro de capas apagadas, compartilhado entre os aparelhos.
///
/// POR QUE EXISTE: as capas viajam pelo `biblioteca.dat` e cada lado MESCLA o
/// que tem com o que está no arquivo — e mesclagem só sabe somar. Sem isto, uma
/// foto apagada no Mac volta na sincronização seguinte do iPhone, que ainda a
/// tem em `Documents/capas/`. Aconteceu em 10/09/2026 com quatro fotos órfãs.
///
/// Arquivo separado do `.dat` de propósito: mudar o formato do `.dat` quebraria
/// toda versão já instalada. Um app antigo simplesmente ignora este arquivo.
///
/// Contrato completo em `comum/exclusao-de-fotos.md`.
enum RegistroExclusoes {

    /// Entradas mais antigas que isto são descartadas: passado esse prazo,
    /// qualquer aparelho que ainda tivesse a foto já teria sincronizado.
    static let validadeEmDias = 90

    private static let nomeArquivo = "biblioteca-removidas.json"

    private static let formatador: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// O que fazer com uma capa que existe no aparelho, diante do registro.
    enum Destino: Equatable {
        /// Nenhuma exclusão pendente: a capa entra no .dat.
        case manter
        /// Foi apagada em algum aparelho e não foi refotografada: sai daqui também.
        case apagar
        /// Foi refotografada DEPOIS de apagada — a exclusão está superada.
        case exclusaoSuperada
    }

    /// Regra central, isolada para poder ser testada sem tocar em disco.
    static func destino(fotoId: String,
                        modificadaEm: Date,
                        registro: [String: Date]) -> Destino {
        guard let quandoApagada = registro[fotoId] else { return .manter }
        return modificadaEm > quandoApagada ? .exclusaoSuperada : .apagar
    }

    private static func url(naPasta pasta: URL) -> URL {
        pasta.appendingPathComponent(nomeArquivo)
    }

    /// Lê o registro: fotoId → quando foi apagada.
    static func ler(naPasta pasta: URL?) -> [String: Date] {
        guard let pasta,
              let dados = try? Data(contentsOf: url(naPasta: pasta)),
              let bruto = try? JSONSerialization.jsonObject(with: dados) as? [String: String]
        else { return [:] }

        let limite = Date().addingTimeInterval(-Double(validadeEmDias) * 86_400)
        var reg: [String: Date] = [:]
        for (id, carimbo) in bruto {
            if let data = formatador.date(from: carimbo), data > limite {
                reg[id] = data
            }
        }
        return reg
    }

    /// Acrescenta exclusões ao registro, com o carimbo de agora.
    static func registrar(_ ids: [String], naPasta pasta: URL?) {
        guard let pasta, !ids.isEmpty else { return }
        var reg = ler(naPasta: pasta)
        let agora = Date()
        for id in ids { reg[id] = agora }
        gravar(reg, naPasta: pasta)
    }

    /// Remove ids do registro — usado quando o usuário refotografa uma capa que
    /// havia apagado: a exclusão está superada.
    static func esquecer(_ ids: [String], naPasta pasta: URL?) {
        guard let pasta, !ids.isEmpty else { return }
        var reg = ler(naPasta: pasta)
        var mudou = false
        for id in ids where reg.removeValue(forKey: id) != nil { mudou = true }
        if mudou { gravar(reg, naPasta: pasta) }
    }

    private static func gravar(_ reg: [String: Date], naPasta pasta: URL) {
        let serializavel = reg.mapValues { formatador.string(from: $0) }
        guard let dados = try? JSONSerialization.data(
            withJSONObject: serializavel, options: [.prettyPrinted, .sortedKeys]
        ) else { return }

        var coordErro: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url(naPasta: pasta),
                                       options: .forReplacing,
                                       error: &coordErro) { u in
            try? dados.write(to: u, options: .atomic)
        }
    }
}
