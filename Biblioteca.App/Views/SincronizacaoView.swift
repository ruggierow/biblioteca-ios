import SwiftUI
import UniformTypeIdentifiers

struct SincronizacaoView: View {
    @EnvironmentObject var store: BibliotecaStore
    @State private var mostrarSeletor = false

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
                    Label(store.arquivoURL == nil ? "Selecionar Biblioteca.txt" : "Trocar arquivo", systemImage: "doc.badge.plus")
                }

                Button {
                    store.recarregarArquivo()
                } label: {
                    Label("Recarregar arquivo", systemImage: "arrow.clockwise")
                }
                .disabled(store.arquivoURL == nil)
            }

            Section {
                Label("No Mac, coloque o biblioteca.txt no iCloud Drive e aponte o app do Mac para ele.",
                      systemImage: "1.circle.fill")
                Label("Aqui no iPhone, toque em Selecionar e escolha esse mesmo arquivo no iCloud Drive.",
                      systemImage: "2.circle.fill")
                Label("As alterações sincronizam automaticamente; o app recarrega ao ser reaberto.",
                      systemImage: "arrow.triangle.2.circlepath")
            } header: {
                Text("Como sincronizar com o Mac")
            } footer: {
                Text("Se editar no Mac e no iPhone ao mesmo tempo, vale a última gravação do arquivo.")
            }
        }
        .navigationTitle("Sincronização")
        .tint(.bibPrimary)
        .fileImporter(
            isPresented: $mostrarSeletor,
            allowedContentTypes: [.text],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.vincularArquivo(url)
            }
        }
    }
}
