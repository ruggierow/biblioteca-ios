import SwiftUI
import UniformTypeIdentifiers

struct SincronizacaoView: View {
    @EnvironmentObject var store: BibliotecaStore
    @State private var mostrarSeletor = false
    @State private var feedbackGravar: String? = nil
    @State private var feedbackSucesso = false
    @State private var feedbackRecarregar: String? = nil
    @State private var feedbackRecarregarSucesso = false

    private var noICloud: Bool {
        guard let url = store.arquivoURL else { return false }
        return FileManager.default.isUbiquitousItem(at: url)
    }

    var body: some View {
        List {
            Section(t("arquivo")) {
                if let arquivoURL = store.arquivoURL {
                    LabeledContent(t("selecionado"), value: arquivoURL.lastPathComponent)
                    LabeledContent(t("livrosCarregadosRotulo"), value: "\(store.livros.count)")
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
                    LabeledContent("iCloud Drive") {
                        Label(noICloud ? t("sim") : t("nao"),
                              systemImage: noICloud ? "checkmark.icloud.fill" : "icloud.slash")
                            .foregroundStyle(noICloud ? Color.bibAccent : Color.bibDanger)
                    }
                } else {
                    Text(t("nenhumArquivoVinculado"))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button {
                    mostrarSeletor = true
                } label: {
                    Label(store.arquivoURL == nil ? t("selecionarPastaBiblioteca") : t("trocarPasta"), systemImage: "folder.badge.plus")
                }

                Button {
                    store.erroMensagem = nil
                    store.recarregarArquivo()
                    FotoStore.shared.sincronizarComDat()
                    if let erro = store.erroMensagem {
                        feedbackRecarregar = erro
                        feedbackRecarregarSucesso = false
                    } else {
                        feedbackRecarregar = t("arquivoEFotosRecarregados")
                        feedbackRecarregarSucesso = true
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            feedbackRecarregar = nil
                        }
                    }
                } label: {
                    Label(t("recarregarDoICloud"), systemImage: "arrow.clockwise")
                }
                .disabled(store.arquivoURL == nil)

                if let texto = feedbackRecarregar {
                    Label(texto, systemImage: feedbackRecarregarSucesso ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(feedbackRecarregarSucesso ? Color.bibAccent : Color.bibDanger)
                }

                Button {
                    store.erroMensagem = nil
                    store.salvar()
                    feedbackGravar = t("gravandoFotos")
                    feedbackSucesso = true
                    if let erro = store.erroMensagem {
                        feedbackGravar = erro
                        feedbackSucesso = false
                    } else {
                        FotoStore.shared.publicarNoICloud { erroDat in
                            if let erroDat {
                                feedbackGravar = erroDat
                                feedbackSucesso = false
                            } else {
                                feedbackGravar = t("textoEFotosGravados")
                                feedbackSucesso = true
                                Task {
                                    try? await Task.sleep(for: .seconds(4))
                                    feedbackGravar = nil
                                }
                            }
                        }
                    }
                } label: {
                    Label(t("gravarNoICloud"), systemImage: "icloud.and.arrow.up")
                }
                .disabled(store.arquivoURL == nil)

                if let texto = feedbackGravar {
                    Label(texto, systemImage: feedbackSucesso ? "checkmark.icloud.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(feedbackSucesso ? Color.bibAccent : Color.bibDanger)
                }
            }

            Section {
                Label(t("passoMac1"),
                      systemImage: "1.circle.fill")
                Label(t("passoMac2"),
                      systemImage: "2.circle.fill")
                Label(t("passoMac3"),
                      systemImage: "arrow.triangle.2.circlepath")
            } header: {
                Text(t("comoSincronizarComMac"))
            } footer: {
                Text(t("avisoEdicaoSimultanea"))
            }
        }
        .navigationTitle(t("sincronizacao"))
        .tint(.bibPrimary)
        .fileImporter(
            isPresented: $mostrarSeletor,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.vincularPasta(url)
            }
        }
    }
}
