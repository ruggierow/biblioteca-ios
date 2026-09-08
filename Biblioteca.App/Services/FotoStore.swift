import UIKit

/// Gerencia fotos de capa, armazenadas como JPEG em Documents/capas/.
/// Sincroniza com iCloud via biblioteca.dat (JSON: { fotoId: "data:image/jpeg;base64,..." })
/// quando iCloudDatURL e iCloudArquivoURL estiverem definidos (pelo BibliotecaStore).
final class FotoStore {
    static let shared = FotoStore()

    private let dir: URL

    /// URL do arquivo biblioteca.dat no iCloud (derivado de biblioteca.txt).
    var iCloudDatURL: URL? = nil

    /// URL com security scope da PASTA do iCloud — cobre biblioteca.dat e outros
    /// arquivos novos criados na mesma pasta.
    var iCloudPastaURL: URL? = nil

    private var datWorkItem: DispatchWorkItem?

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("capas", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func salvar(_ imagem: UIImage, livroId: String) {
        guard !livroId.isEmpty, let data = imagem.jpegData(compressionQuality: 0.82) else { return }
        try? data.write(to: urlPara(livroId), options: .atomic)
        publicarNoICloud()
    }

    func carregar(livroId: String) -> UIImage? {
        guard !livroId.isEmpty,
              let data = try? Data(contentsOf: urlPara(livroId)) else { return nil }
        return UIImage(data: data)
    }

    func remover(livroId: String) {
        guard !livroId.isEmpty else { return }
        try? FileManager.default.removeItem(at: urlPara(livroId))
        publicarNoICloud()
    }

    func existe(livroId: String) -> Bool {
        guard !livroId.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: urlPara(livroId).path)
    }

    /// Move a foto de `idAntigo` para `idNovo` quando título/autores mudam.
    func migrar(de idAntigo: String, para idNovo: String) {
        guard idAntigo != idNovo, existe(livroId: idAntigo) else { return }
        if let foto = carregar(livroId: idAntigo) {
            salvar(foto, livroId: idNovo)
            remover(livroId: idAntigo)
        }
    }

    // MARK: - Sincronização com iCloud (biblioteca.dat)

    /// Lê biblioteca.dat do iCloud e salva localmente as fotos ausentes.
    func sincronizarComDat() {
        guard let datURL = iCloudDatURL else { return }
        let fm = FileManager.default
        guard fm.fileExists(atPath: datURL.path) else { return }

        if (try? datURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
            .ubiquitousItemDownloadingStatus == .some(.notDownloaded) {
            try? fm.startDownloadingUbiquitousItem(at: datURL)
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }

            var texto = ""
            var coordError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: datURL, options: [], error: &coordError) { u in
                texto = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
            }
            guard !texto.isEmpty,
                  let dict = try? JSONSerialization.jsonObject(
                    with: Data(texto.utf8)) as? [String: String]
            else { return }

            for (fotoId, dataURI) in dict {
                if self.existe(livroId: fotoId) { continue }
                guard let commaIdx = dataURI.firstIndex(of: ",") else { continue }
                let base64 = String(dataURI[dataURI.index(after: commaIdx)...])
                guard let data = Data(base64Encoded: base64) else { continue }
                try? data.write(to: self.urlPara(fotoId), options: .atomic)
            }
        }
    }

    /// Agenda (com debounce de 1 s) a publicação de todas as fotos locais em biblioteca.dat.
    func publicarNoICloud() {
        guard iCloudDatURL != nil, iCloudPastaURL != nil else { return }
        datWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.escreverDat() }
        datWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    private func escreverDat() {
        guard let datURL = iCloudDatURL else { return }

        DispatchQueue.global(qos: .background).async {
            // Monta dicionário { fotoId: "data:image/jpeg;base64,..." }
            var dict: [String: String] = [:]
            let fm = FileManager.default
            guard let arquivos = try? fm.contentsOfDirectory(
                at: self.dir, includingPropertiesForKeys: nil) else { return }
            for arquivo in arquivos where arquivo.pathExtension == "jpg" {
                let fotoId = arquivo.deletingPathExtension().lastPathComponent
                guard let data = try? Data(contentsOf: arquivo) else { continue }
                dict[fotoId] = "data:image/jpeg;base64," + data.base64EncodedString()
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let jsonStr = String(data: jsonData, encoding: .utf8)
            else { return }

            // Scope da pasta mantido ativo pelo BibliotecaStore — não precisa
            // de start/stop aqui.
            var coordError: NSError?
            NSFileCoordinator().coordinate(
                writingItemAt: datURL, options: .forReplacing, error: &coordError
            ) { u in
                try? jsonStr.write(to: u, atomically: true, encoding: .utf8)
            }
        }
    }

    private func urlPara(_ id: String) -> URL {
        dir.appendingPathComponent(id + ".jpg")
    }
}
