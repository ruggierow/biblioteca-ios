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
                    ComentariosComLinksView(texto: livro.comentarios, titulo: livro.titulo)
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
    let titulo: String

    @State private var copiado = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(textoComLinks)
                .font(.body)
                .textSelection(.enabled)
            if copiado {
                Text("Título copiado — cole na busca do Kindle.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        // O aplicativo Kindle abre na BIBLIOTECA, nunca no livro: o esquema
        // `kindle://` nao tem rota de busca. Entao, ao tocar nesse link, o
        // titulo vai para a area de transferencia e basta colar na busca dele.
        //
        // So no link do Kindle: o do leitor da web abre o livro sozinho, e
        // mexer na area de transferencia a toa apagaria o que o usuario copiou.
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme?.lowercased() == "kindle" {
                UIPasteboard.general.string = titulo
                withAnimation { copiado = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { copiado = false }
                }
            }
            return .systemAction
        })
    }

    /// Monta o texto com os links mostrando o ROTULO, nao o endereco.
    ///
    /// Antes aparecia a URL inteira: funcionava, mas ocupava varias linhas e
    /// no Android chegava a empurrar o resto da secao para fora da tela. Agora
    /// as quatro plataformas mostram a mesma coisa — "Ler | Kindle" — e o
    /// endereco so aparece na impressao, que e papel e nao se clica.
    private var textoComLinks: AttributedString {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return AttributedString(texto)
        }

        var saida = AttributedString("")
        var fim = texto.startIndex
        let nsRange = NSRange(texto.startIndex..<texto.endIndex, in: texto)

        for resultado in detector.matches(in: texto, options: [], range: nsRange) {
            guard let url = resultado.url,
                  let range = Range(resultado.range, in: texto) else { continue }

            var antes = String(texto[fim..<range.lowerBound])
            let achado = String(texto[range])
            var nome: String

            if let (prefixo, rotulo) = separarRotulo(antes) {
                nome = rotulo
                antes = prefixo
            } else if achado.lowercased().hasPrefix("kindle:") {
                nome = "app Kindle"
            } else {
                nome = url.host ?? achado
                if nome.lowercased().hasPrefix("www.") { nome = String(nome.dropFirst(4)) }
            }

            saida.append(AttributedString(antes))
            var link = AttributedString(nome)
            link.link = normalizarURL(url)
            link.foregroundColor = .bibPrimary
            link.underlineStyle = .single
            saida.append(link)
            fim = range.upperBound
        }

        saida.append(AttributedString(String(texto[fim...])))
        return saida
    }

    private func normalizarURL(_ url: URL) -> URL {
        if url.scheme == nil, let urlComHTTPS = URL(string: "https://\(url.absoluteString)") {
            return urlComHTTPS
        }
        return url
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

// MARK: - Rotulo do link

/// Separa "texto comum" de "Rotulo:" imediatamente antes de um endereco.
///
/// Devolve o texto que fica na tela e o rotulo que vira o toque — ou nil
/// quando nao ha rotulo. Para em pontuacao de frase: sem isso,
/// "…funesto. Ler: http…" devolveria meia frase como rotulo.
func separarRotulo(_ antes: String) -> (prefixo: String, rotulo: String)? {
    guard let regex = try? NSRegularExpression(
        pattern: "([^|;\u{00b7}.,!?\n]{1,30}?)\\s*:\\s*$") else { return nil }
    let faixa = NSRange(antes.startIndex..<antes.endIndex, in: antes)
    guard let m = regex.firstMatch(in: antes, options: [], range: faixa),
          let inteiro = Range(m.range, in: antes),
          let grupo = Range(m.range(at: 1), in: antes) else { return nil }

    let rotulo = antes[grupo].trimmingCharacters(in: .whitespaces)
    guard !rotulo.isEmpty else { return nil }

    var prefixo = String(antes[antes.startIndex..<inteiro.lowerBound])
    prefixo = String(prefixo.reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
    if !prefixo.isEmpty { prefixo += " " }
    return (prefixo, rotulo)
}
