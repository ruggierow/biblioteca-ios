import UIKit

extension Notification.Name {
    /// Postada na main queue sempre que novas fotos chegam do iCloud.
    static let fotosSincronizadas = Notification.Name("FotoStore.fotosSincronizadas")
}

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
            // Tenta de novo após o download completar.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.sincronizarComDat()
            }
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

            var salvouAlguma = false
            for (fotoId, dataURI) in dict {
                if self.existe(livroId: fotoId) { continue }
                guard let commaIdx = dataURI.firstIndex(of: ",") else { continue }
                let base64 = String(dataURI[dataURI.index(after: commaIdx)...])
                guard let data = Data(base64Encoded: base64) else { continue }
                try? data.write(to: self.urlPara(fotoId), options: .atomic)
                salvouAlguma = true
            }
            if salvouAlguma {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .fotosSincronizadas, object: nil)
                }
            }
        }
    }

    /// Agenda (com debounce de 1 s) a publicação de todas as fotos locais em biblioteca.dat.
    /// Chama o completion na main queue com nil (sucesso) ou mensagem de erro.
    func publicarNoICloud(completion: ((String?) -> Void)? = nil) {
        guard iCloudDatURL != nil, iCloudPastaURL != nil else {
            completion?("Pasta do iCloud não vinculada.")
            return
        }
        datWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.escreverDat(completion: completion) }
        datWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    private func escreverDat(completion: ((String?) -> Void)? = nil) {
        guard let datURL = iCloudDatURL else {
            DispatchQueue.main.async { completion?("URL do dat não definida.") }
            return
        }
        let fm = FileManager.default

        // Se o dat existe mas ainda não foi baixado do iCloud, aguarda o download.
        if fm.fileExists(atPath: datURL.path) {
            let status = (try? datURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
                .ubiquitousItemDownloadingStatus
            if status == .notDownloaded {
                try? fm.startDownloadingUbiquitousItem(at: datURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.escreverDat(completion: completion)
                }
                return
            }
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }

            // Monta dicionário das fotos locais.
            var dictLocal: [String: String] = [:]
            if let arquivos = try? fm.contentsOfDirectory(at: self.dir, includingPropertiesForKeys: nil) {
                for arquivo in arquivos where arquivo.pathExtension == "jpg" {
                    let fotoId = arquivo.deletingPathExtension().lastPathComponent
                    if let data = try? Data(contentsOf: arquivo) {
                        dictLocal[fotoId] = "data:image/jpeg;base64," + data.base64EncodedString()
                    }
                }
            }

            guard !dictLocal.isEmpty else {
                DispatchQueue.main.async { completion?("Nenhuma foto local para gravar.") }
                return
            }

            // Merge com dat existente via NSFileCoordinator.
            var coordError: NSError?
            var escreveu = false
            NSFileCoordinator().coordinate(
                readingItemAt: datURL, options: [],
                writingItemAt: datURL, options: .forReplacing,
                error: &coordError
            ) { readURL, writeURL in
                var dictFinal: [String: String] = [:]
                if fm.fileExists(atPath: readURL.path),
                   let texto = try? String(contentsOf: readURL, encoding: .utf8),
                   let existente = try? JSONSerialization.jsonObject(with: Data(texto.utf8)) as? [String: String] {
                    dictFinal = existente
                }
                // Sobrepõe com fotos locais (independente de erro de leitura — nunca perde fotos locais).
                for (k, v) in dictLocal { dictFinal[k] = v }
                if let jsonData = try? JSONSerialization.data(withJSONObject: dictFinal),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    do {
                        try jsonStr.write(to: writeURL, atomically: true, encoding: .utf8)
                        escreveu = true
                    } catch {}
                }
            }

            if coordError != nil && !escreveu {
                // Fallback sem coordenação quando o coordinator falha.
                var dictFinal: [String: String] = [:]
                if fm.fileExists(atPath: datURL.path),
                   let texto = try? String(contentsOf: datURL, encoding: .utf8),
                   let existente = try? JSONSerialization.jsonObject(with: Data(texto.utf8)) as? [String: String] {
                    dictFinal = existente
                }
                for (k, v) in dictLocal { dictFinal[k] = v }
                if let jsonData = try? JSONSerialization.data(withJSONObject: dictFinal),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    escreveu = (try? jsonStr.write(to: datURL, atomically: true, encoding: .utf8)) != nil
                }
            }

            DispatchQueue.main.async {
                if escreveu {
                    completion?(nil)
                } else {
                    completion?("Erro ao gravar fotos: \(coordError?.localizedDescription ?? "falha desconhecida")")
                }
            }
        }
    }

    private func urlPara(_ id: String) -> URL {
        dir.appendingPathComponent(id + ".jpg")
    }
}
