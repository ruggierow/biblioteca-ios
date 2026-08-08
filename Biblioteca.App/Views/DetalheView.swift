import SwiftUI

struct DetalheView: View {
    @EnvironmentObject var store: BibliotecaStore
    var livro: Livro

    @State private var mostrarEdicao = false

    var body: some View {
        List {
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
                LabeledContent("Grupo de literatura", value: livro.grupoLiteratura ? "Sim" : "Não")
            }

            if !livro.comentarios.isEmpty {
                Section("Comentários") {
                    Text(livro.comentarios)
                        .font(.body)
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
        .sheet(isPresented: $mostrarEdicao) {
            CadastroView(livroEditando: livro)
        }
    }
}
