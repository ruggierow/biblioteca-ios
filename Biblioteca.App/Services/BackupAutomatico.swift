import Foundation

/// Cópia de segurança automática do `biblioteca.txt` e do `biblioteca.dat`.
///
/// Mesmas regras dos apps de Mac e Windows (ver `comum/permissoes.md` e o
/// `CLAUDE.md` do projeto):
///
/// - **Antes da primeira gravação da sessão**, não no fim. Se o app for
///   encerrado pelo sistema ou travar, não há "fim de sessão" — e um backup do
///   que se está deixando é justamente o que já está no arquivo. Copiando antes,
///   preserva-se o último estado bom.
/// - **Só copia se o conteúdo mudou** em relação ao backup mais recente. Por
///   data de modificação geraria cópias inúteis: o `.dat` é reescrito em
///   situações que não alteram nada.
/// - **Rotação**: 30 gerações do `.txt` (pequeno) e 7 do `.dat` (~9 MB cada).
///
/// Os arquivos vão para `Backups/` dentro da pasta vinculada — a mesma que o
/// Mac usa, então as cópias do iPhone e as do Mac convivem no iCloud.
enum BackupAutomatico {

    static let maximoTxt = 30
    static let maximoDat = 7

    /// Uma vez por execução do app, por arquivo.
    private static var jaFeito = Set<String>()

    /// Carimbo do início da sessão — o backup guarda o estado em que ela começou.
    private static let sufixoSessao: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH'h'mm"
        return f.string(from: Date())
    }()

    /// Copia `arquivo` para `Backups/` se ainda não houve backup dele nesta
    /// sessão e se o conteúdo difere do backup mais recente.
    ///
    /// Silencioso de propósito: uma falha de backup não pode impedir o usuário
    /// de salvar o trabalho dele.
    static func executar(para arquivo: URL, maximo: Int) {
        let chave = arquivo.lastPathComponent
        guard !jaFeito.contains(chave) else { return }
        jaFeito.insert(chave)   // marca antes: se falhar, não insiste a cada gravação

        let fm = FileManager.default
        guard fm.fileExists(atPath: arquivo.path),
              let atual = try? Data(contentsOf: arquivo) else { return }

        let pasta = arquivo.deletingLastPathComponent().appendingPathComponent("Backups")
        let base = arquivo.deletingPathExtension().lastPathComponent
        let ext = arquivo.pathExtension
        let prefixo = base + "_"

        let anteriores = ((try? fm.contentsOfDirectory(at: pasta,
                                                       includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(prefixo) && $0.pathExtension == ext }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        if let ultimo = anteriores.last,
           let anterior = try? Data(contentsOf: ultimo),
           anterior == atual {
            return   // nada mudou desde o último backup
        }

        try? fm.createDirectory(at: pasta, withIntermediateDirectories: true)
        let destino = pasta.appendingPathComponent("\(prefixo)\(sufixoSessao).\(ext)")
        do {
            try atual.write(to: destino, options: .atomic)
        } catch {
            print("backup automático falhou:", error)
            return
        }

        // Rotação: mantém os `maximo` mais recentes. Os nomes trazem a data em
        // AAAA-MM-DD_HHhMM, que ordena igual cronologicamente.
        var todos = anteriores
        todos.append(destino)
        if todos.count > maximo {
            for antigo in todos.prefix(todos.count - maximo) {
                try? fm.removeItem(at: antigo)
            }
        }
    }
}
