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
            Section("Arquivo") {
                if let arquivoURL = store.arquivoURL {
                    LabeledContent("Selecionado", value: arquivoURL.lastPathComponent)
                    LabeledContent("Livros carregados", value: "\(store.livros.count)")
                    if let quando = store.ultimaRecarga {
                        LabeledContent("Recarregado") {
                            Label(quando.formatted(date: .omitted, time: .shortened),
                                  systemImage: "arrow.clockwise.circle.fill")
                                .foregroundStyle(Color.bibAccent)
                        }
                    }
                    if let quando = store.ultimaGravacao {
                        LabeledContent("Salvo") {
                            Label(quando.formatted(date: .omitted, time: .shortened),
                                  systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.bibAccent)
                        }
                    }
                    LabeledContent("iCloud Drive") {
                        Label(noICloud ? "Sim" : "Não",
                              systemImage: noICloud ? "checkmark.icloud.fill" : "icloud.slash")
                            .foregroundStyle(noICloud ? Color.bibAccent : Color.bibDanger)
                    }
                } else {
                    Text("Nenhum arquivo vinculado")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button {
                    mostrarSeletor = true
                } label: {
                    Label(store.arquivoURL == nil ? "Selecionar pasta Biblioteca" : "Trocar pasta", systemImage: "folder.badge.plus")
                }

                Button {
                    store.erroMensagem = nil
                    store.recarregarArquivo()
                    if let erro = store.erroMensagem {
                        feedbackRecarregar = erro
                        feedbackRecarregarSucesso = false
                    } else {
                        feedbackRecarregar = "Arquivo recarregado com sucesso."
                        feedbackRecarregarSucesso = true
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            feedbackRecarregar = nil
                        }
                    }
                } label: {
                    Label("Recarregar do iCloud", systemImage: "arrow.clockwise")
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
                    FotoStore.shared.publicarNoICloud()
                    if let erro = store.erroMensagem {
                        feedbackGravar = erro
                        feedbackSucesso = false
                    } else {
                        feedbackGravar = "Arquivo gravado com sucesso no iCloud."
                        feedbackSucesso = true
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            feedbackGravar = nil
                        }
                    }
                } label: {
                    Label("Gravar no iCloud", systemImage: "icloud.and.arrow.up")
                }
                .disabled(store.arquivoURL == nil)

                if let texto = feedbackGravar {
                    Label(texto, systemImage: feedbackSucesso ? "checkmark.icloud.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(feedbackSucesso ? Color.bibAccent : Color.bibDanger)
                }
            }

            Section {
                Label("No Mac, coloque o biblioteca.txt no iCloud Drive e abra o app do Mac.",
                      systemImage: "1.circle.fill")
                Label("Aqui no iPhone, toque em Selecionar e escolha a pasta Biblioteca no iCloud Drive (não o arquivo).",
                      systemImage: "2.circle.fill")
                Label("Antes de editar aqui, toque em Recarregar do iCloud se você alterou a base no Mac.",
                      systemImage: "arrow.triangle.2.circlepath")
            } header: {
                Text("Como sincronizar com o Mac")
            } footer: {
                Text("Evite editar no Mac e no iPhone ao mesmo tempo. Como a base é um arquivo compartilhado, pode valer a última gravação.")
            }
        }
        .navigationTitle("Sincronização")
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
