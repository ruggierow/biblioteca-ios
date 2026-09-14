import SwiftUI

/// A folha de filtros da pesquisa — o equivalente da barra "Pesquisar e
/// filtrar" do Mac e do Windows, num formato que cabe no polegar.
struct FiltrosView: View {
    @Binding var filtro: FiltroPesquisa
    let grupos: [Grupo]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Picker("Status", selection: $filtro.status) {
                        ForEach(FiltroStatus.allCases) { s in
                            Text(s.rotulo).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Grupo de literatura") {
                    Picker("Grupo", selection: $filtro.grupo) {
                        Text("Todos os livros").tag(FiltroGrupo.todos)
                        Text("Qualquer grupo").tag(FiltroGrupo.qualquer)
                        ForEach(grupos) { g in
                            Text(g.nome).tag(FiltroGrupo.especifico(g.id))
                        }
                    }
                    .labelsHidden()
                }

                Section {
                    Toggle("Só livros com foto", isOn: $filtro.comFoto)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.bibPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar") { filtro.limpar() }
                        .disabled(filtro.quantosLigados == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Pronto") { dismiss() }.bold()
                }
            }
        }
    }
}
