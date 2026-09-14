import SwiftUI
import Foundation

struct DetalheView: View {
    @EnvironmentObject var store: BibliotecaStore
    let livroId: UUID

    @State private var mostrarEdicao = false
    @State private var capa: UIImage? = nil

    // Sempre lê o livro atualizado do store — reflete edições sem sair da tela.
    private var livro: Livro {
        store.livros.first { $0.id == livroId } ?? Livro()
    }

    var body: some View {
        List {
            // Foto da capa — mostra foto real ou ícone do app como placeholder
            Section {
                Group {
                    if let capa {
                        Image(uiImage: capa)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    } else {
                        CapaSemFotoView()
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            }

            Section("Identificação") {
                LabeledContent("Título", value: livro.titulo)
                if !livro.ano.isEmpty {
                    LabeledContent("Ano", value: livro.ano)
                }
                if !livro.local.isEmpty {
                    LabeledContent("Local", value: livro.local)
                }
            }

            if !livro.autores.filter({ !$0.isEmpty }).isEmpty {
                Section("Autor(es)") {
                    ForEach(livro.autores.filter { !$0.isEmpty }, id: \.self) {
                        Text($0)
                    }
                }
            }

            if !livro.temas.filter({ !$0.isEmpty }).isEmpty {
                Section("Tema(s)") {
                    ForEach(livro.temas.filter { !$0.isEmpty }, id: \.self) {
                        Text($0)
                    }
                }
            }

            Section("Status") {
                LabeledContent("Emprestado", value: livro.emprestado ? "Sim" : "Não")
                LabeledContent("Grupo de literatura",
                               value: livro.listaGrupos.isEmpty
                                    ? "Não"
                                    : livro.listaGrupos.map(GruposStore.shared.nome).joined(separator: ", "))
            }

            if !livro.comentarios.isEmpty {
                Section("Comentários") {
                    ComentariosComLinksView(texto: livro.comentarios)
                }
            }
        }
        .navigationTitle(livro.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.bibPrimary)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { mostrarEdicao = true }
            }
        }
        .sheet(isPresented: $mostrarEdicao, onDismiss: {
            // Após edição, o id pode ter mudado; busca o livro atualizado no store
            if let livroAtual = store.livros.first(where: { $0.id == livro.id }) {
                capa = FotoStore.shared.carregar(livroId: livroAtual.fotoId)
            }
        }) {
            CadastroView(livroEditando: livro)
        }
        .onAppear {
            capa = FotoStore.shared.carregar(livroId: livro.fotoId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fotosSincronizadas)) { _ in
            capa = FotoStore.shared.carregar(livroId: livro.fotoId)
        }
    }
}

private struct ComentariosComLinksView: View {
    let texto: String

    var body: some View {
        Text(textoComLinks)
            .font(.body)
            .textSelection(.enabled)
    }

    private var textoComLinks: AttributedString {
        var attributed = AttributedString(texto)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }

        let nsRange = NSRange(texto.startIndex..<texto.endIndex, in: texto)
        for resultado in detector.matches(in: texto, options: [], range: nsRange) {
            guard let url = resultado.url,
                  let range = Range(resultado.range, in: texto),
                  let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed) else {
                continue
            }

            let urlNormalizada = normalizarURL(url)
            attributed[lower..<upper].link = kindleURL(para: urlNormalizada) ?? urlNormalizada
            attributed[lower..<upper].foregroundColor = .bibPrimary
            attributed[lower..<upper].underlineStyle = .single
        }
        return attributed
    }

    private func normalizarURL(_ url: URL) -> URL {
        if url.scheme == nil, let urlComHTTPS = URL(string: "https://\(url.absoluteString)") {
            return urlComHTTPS
        }
        return url
    }

    private func kindleURL(para url: URL) -> URL? {
        guard let asin = asinExtraido(de: url) else { return nil }
        return URL(string: "kindle://book?action=open&asin=\(asin)")
    }

    private func asinExtraido(de url: URL) -> String? {
        if let asin = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { ["asin", "ASIN"].contains($0.name) })?
            .value {
            return asinLimpo(asin)
        }

        let componentes = url.pathComponents
        for marcador in ["dp", "gp", "product"] {
            if let indice = componentes.firstIndex(of: marcador), componentes.indices.contains(indice + 1) {
                if let asin = asinLimpo(componentes[indice + 1]) {
                    return asin
                }
            }
        }

        return componentes.compactMap(asinLimpo).first
    }

    private func asinLimpo(_ valor: String) -> String? {
        let filtrado = valor.uppercased().filter { $0.isLetter || $0.isNumber }
        guard filtrado.count == 10 else { return nil }
        return filtrado
    }
}

// Placeholder exibido quando o livro não tem foto — usa o ícone do próprio app.
private struct CapaSemFotoView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
                .frame(maxWidth: .infinity)
                .frame(height: 150)

            VStack(spacing: 10) {
                Image("IconeApp")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                Text("Sem foto da capa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
