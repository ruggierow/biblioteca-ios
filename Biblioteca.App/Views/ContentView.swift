import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: BibliotecaStore

    @State private var mostrarScanner = false
    @State private var isbnEscaneado: String? = nil

    private var versaoApp: String {
        let versao = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "v.\(versao ?? "1.0.0")"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        .bibPrimary,
                        Color(red: 0xd8 / 255, green: 0xf3 / 255, blue: 0xdc / 255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    Section {
                        HomeHeader(livrosCount: store.livros.count, versionText: versaoApp)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    Section {
                        Button {
                            mostrarScanner = true
                        } label: {
                            Label(t("escanearLivro"), systemImage: "barcode.viewfinder")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.bibAccent)
                        .disabled(store.arquivoURL == nil)
                    }
                    .listRowBackground(Color.white.opacity(0.92))

                    Section {
                        NavigationLink {
                            CadastroView()
                        } label: {
                            MenuRow(icon: "plus.circle", title: t("menuCadastro"))
                        }
                        .disabled(store.arquivoURL == nil)

                        NavigationLink {
                            PaisesView()
                        } label: {
                            MenuRow(icon: "globe", title: t("menuPaises"))
                        }
                        .disabled(store.arquivoURL == nil)

                        NavigationLink {
                            PesquisaView()
                        } label: {
                            MenuRow(icon: "magnifyingglass", title: t("menuPesquisa"))
                        }
                        .disabled(store.arquivoURL == nil)

                        NavigationLink {
                            SincronizacaoView()
                        } label: {
                            MenuRow(icon: "arrow.triangle.2.circlepath", title: t("menuSincronizacao"))
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.92))

                    Section {
                        if let arquivoURL = store.arquivoURL {
                            LabeledContent(t("selecionado"), value: arquivoURL.lastPathComponent)
                            if let local = store.localAmigavel {
                                LabeledContent(t("local"), value: local)
                            }
                            LabeledContent(t("livros"), value: "\(store.livros.count)")
                            if let quando = store.ultimaRecarga {
                                LabeledContent(t("recarregado")) {
                                    Label(quando.formatted(date: .omitted, time: .shortened),
                                          systemImage: "arrow.clockwise.circle.fill")
                                        .foregroundStyle(Color.bibAccent)
                                }
                            }
                            if let quando = store.ultimaGravacao {
                                LabeledContent(t("salvo")) {
                                    Label(quando.formatted(date: .omitted, time: .shortened),
                                          systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(Color.bibAccent)
                                }
                            }
                            DisclosureGroup(t("caminhoCompleto")) {
                                Text(store.caminhoCompleto ?? "-")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        } else {
                            Text(t("nenhumArquivoVinculado"))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text(t("arquivo"))
                    } footer: {
                        Text(t("salvasAutomaticamente"))
                    }
                    .listRowBackground(Color.white.opacity(0.92))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(.bibPrimary)
            .alert(t("erro"), isPresented: Binding(
                get: { store.erroMensagem != nil },
                set: { if !$0 { store.erroMensagem = nil } }
            )) {
                Button("OK", role: .cancel) { store.erroMensagem = nil }
            } message: {
                Text(store.erroMensagem ?? "")
            }
            .sheet(isPresented: $mostrarScanner) {
                ScannerView(onScanned: { codigo in isbnEscaneado = codigo },
                            onDigitarISBN: { isbnEscaneado = "" })
            }
            .sheet(item: Binding(
                get: { isbnEscaneado.map { IsbnWrapper(valor: $0) } },
                set: { if $0 == nil { isbnEscaneado = nil } }
            )) { wrap in
                CadastroView(isbnInicial: wrap.valor)
            }
        }
    }
}

private struct HomeHeader: View {
    let livrosCount: Int
    let versionText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Biblioteca")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text(t("subtituloApp"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))

            Label(t("livrosCarregados", [livrosCount]), systemImage: "books.vertical.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.top, 6)

            HStack {
                Text(versionText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                SeletorDeIdioma()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }
}

/// A escolha do idioma, no cabeçalho — mesmo lugar que ela ocupa no motor-web
/// e no app Android.
///
/// Discreta, ao lado da versão: o idioma se escolhe uma vez e não se mexe
/// mais. O rótulo mostra a língua EM VIGOR, não a outra.
struct SeletorDeIdioma: View {
    @EnvironmentObject private var idioma: Idioma

    var body: some View {
        Menu {
            Picker("", selection: Binding(
                get: { idioma.atual },
                set: { idioma.trocar($0) }
            )) {
                Text("Português").tag("pt")
                Text("English").tag("en")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text(idioma.atual.uppercased())
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.75))
        }
        .accessibilityLabel(t("idiomaDica"))
    }
}

private struct IsbnWrapper: Identifiable {
    let id = UUID()
    let valor: String
}

private struct MenuRow: View {
    let icon: String
    let title: String

    var body: some View {
        Label {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.bibText)
        } icon: {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.bibPrimary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
        .environmentObject(BibliotecaStore())
}
