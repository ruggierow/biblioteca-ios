import Foundation
import SwiftUI
import Combine

class BibliotecaStore: ObservableObject {
    @Published var livros: [Livro] = []
    @Published var arquivoURL: URL? = nil
    @Published var erroMensagem: String? = nil
    @Published var ultimaGravacao: Date? = nil
    @Published var ultimaRecarga: Date? = nil

    // MARK: - Identificação do arquivo (local visível ao usuário)

    /// Caminho técnico completo do arquivo vinculado.
    var caminhoCompleto: String? {
        arquivoURL?.path(percentEncoded: false)
    }

    /// Localização amigável da pasta do arquivo (ex.: "iCloud Drive › Biblioteca").
    var localAmigavel: String? {
        guard let url = arquivoURL else { return nil }
        let comps = url.deletingLastPathComponent().pathComponents
        if let idx = comps.firstIndex(of: "com~apple~CloudDocs") {
            return (["iCloud Drive"] + comps[(idx + 1)...]).joined(separator: " › ")
        }
        if let idx = comps.firstIndex(where: { $0.hasPrefix("iCloud~") }) {
            var cauda = Array(comps[(idx + 1)...])
            if cauda.first == "Documents" { cauda.removeFirst() }
            return (["iCloud Drive"] + cauda).joined(separator: " › ")
        }
        return comps.last ?? url.lastPathComponent
    }

    private static let SEP = ";"

    // Bookmark agora guarda a PASTA (não o arquivo), para que o security scope
    // cubra a pasta inteira e permita criar biblioteca.dat.
    private static let bookmarkKey = "bibliotecaPastaBookmark"

    // URL com security scope da pasta selecionada.
    private var pastaURL: URL? = nil

    init() {
        restaurarArquivo()
    }

    deinit {
        pastaURL?.stopAccessingSecurityScopedResource()
    }

    // MARK: - Vínculo com pasta

    /// Recebe a URL da PASTA selecionada pelo fileImporter.
    func vincularPasta(_ pasta: URL) {
        guard pasta.startAccessingSecurityScopedResource() else { return }
        do {
            let bookmark = try pasta.bookmarkData(options: .minimalBookmark,
                                                  includingResourceValuesForKeys: nil,
                                                  relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            pastaURL?.stopAccessingSecurityScopedResource()
            pastaURL = pasta
            arquivoURL = pasta.appendingPathComponent("biblioteca.txt")
            configurarFotoStore(para: pasta)
            if let url = arquivoURL {
                carregarDoArquivo(url)
            }
        } catch {
            pasta.stopAccessingSecurityScopedResource()
            erroMensagem = "Erro ao vincular pasta: \(error.localizedDescription)"
        }
    }

    private func restaurarArquivo() {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        var isStale = false
        do {
            let pasta = try URL(resolvingBookmarkData: bookmark,
                                options: .withoutUI,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)
            if isStale {
                UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
                return
            }
            guard pasta.startAccessingSecurityScopedResource() else { return }
            pastaURL = pasta
            let txt = pasta.appendingPathComponent("biblioteca.txt")
            arquivoURL = txt
            configurarFotoStore(para: pasta)
            carregarDoArquivo(txt)
            // Scope mantido ativo — liberado em deinit ou ao trocar de pasta.
        } catch {
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        }
    }

    private func configurarFotoStore(para pasta: URL) {
        let datURL = pasta.appendingPathComponent("biblioteca.dat")
        FotoStore.shared.iCloudDatURL = datURL
        // Escopo de segurança da PASTA: permite criar arquivos novos (biblioteca.dat).
        FotoStore.shared.iCloudPastaURL = pasta
        FotoStore.shared.sincronizarComDat()
        FotoStore.shared.publicarNoICloud()
    }

    func carregarDoArquivo(_ url: URL) {
        do {
            let texto = try lerCoordenado(url)
            livros = parsear(texto)
            ultimaRecarga = Date()
        } catch {
            erroMensagem = "Erro ao carregar: \(error.localizedDescription)"
        }
    }

    /// Lê o arquivo com coordenação (NSFileCoordinator), garantindo o download
    /// caso ele esteja no iCloud Drive e ainda não tenha sido baixado.
    private func lerCoordenado(_ url: URL) throws -> String {
        if (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
            .ubiquitousItemDownloadingStatus == .some(.notDownloaded) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        var coordErro: NSError?
        var lerErro: Error?
        var texto = ""
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordErro) { u in
            do { texto = try String(contentsOf: u, encoding: .utf8) } catch { lerErro = error }
        }
        if let e = coordErro ?? (lerErro as NSError?) { throw e }
        return texto
    }

    func recarregarArquivo() {
        guard pastaURL != nil, let url = arquivoURL else { return }
        carregarDoArquivo(url)
    }

    func salvar() {
        guard pastaURL != nil, let url = arquivoURL else { return }
        // Preserva o último estado bom antes da primeira gravação da sessão.
        BackupAutomatico.executar(para: url, maximo: BackupAutomatico.maximoTxt)
        let texto = serializar()
        var coordErro: NSError?
        var escreverErro: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordErro) { u in
            do { try texto.write(to: u, atomically: true, encoding: .utf8) } catch { escreverErro = error }
        }
        if let e = coordErro ?? (escreverErro as NSError?) {
            erroMensagem = "Erro ao salvar: \(e.localizedDescription)"
        } else {
            ultimaGravacao = Date()
        }
    }

    // MARK: - CRUD

    func adicionar(_ livro: Livro) {
        livros.append(livro)
        salvar()
    }

    func atualizar(_ livro: Livro) {
        guard let idx = livros.firstIndex(where: { $0.id == livro.id }) else { return }
        livros[idx] = livro
        salvar()
    }

    func remover(at offsets: IndexSet) {
        livros.remove(atOffsets: offsets)
        salvar()
    }

    func remover(_ livro: Livro) {
        livros.removeAll { $0.id == livro.id }
        salvar()
    }

    // MARK: - TSV

    func parsear(_ texto: String) -> [Livro] {
        texto.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { linha -> Livro? in
                let c = linha.components(separatedBy: "\t")
                guard c.count >= 1, !c[0].isEmpty else { return nil }
                var l = Livro()
                l.titulo         = c[0]
                l.autores        = c.count > 1 ? split(c[1]) : []
                l.temas          = c.count > 2 ? split(c[2]) : []
                l.ano            = c.count > 3 ? c[3] : ""
                l.emprestado     = c.count > 4 && c[4] == "1"
                l.comentarios    = c.count > 5 ? c[5] : ""
                l.local          = c.count > 6 ? c[6] : ""
                l.grupos = c.count > 7 ? c[7].trimmingCharacters(in: .whitespacesAndNewlines) : "0"
                return l
            }
    }

    private func split(_ campo: String) -> [String] {
        campo.components(separatedBy: Self.SEP)
             .map { $0.trimmingCharacters(in: .whitespaces) }
             .filter { !$0.isEmpty }
    }

    func serializar() -> String {
        livros.map { l in
            [
                l.titulo,
                l.autores.joined(separator: "; "),
                l.temas.joined(separator: "; "),
                l.ano,
                l.emprestado ? "1" : "0",
                l.comentarios,
                l.local,
                l.grupos
            ].joined(separator: "\t")
        }.joined(separator: "\n")
    }
}
