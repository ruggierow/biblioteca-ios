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
                Section(t("status")) {
                    Picker(t("status"), selection: $filtro.status) {
                        ForEach(FiltroStatus.allCases) { s in
                            Text(s.rotulo).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section(t("grupoDeLiteratura")) {
                    Picker(t("grupo"), selection: $filtro.grupo) {
                        Text(t("todosOsLivros")).tag(FiltroGrupo.todos)
                        Text(t("qualquerGrupo")).tag(FiltroGrupo.qualquer)
                        ForEach(grupos) { g in
                            Text(g.nome).tag(FiltroGrupo.especifico(g.id))
                        }
                    }
                    .labelsHidden()
                }

                Section {
                    Toggle(t("soLivrosComFoto"), isOn: $filtro.comFoto)
                }
            }
            .navigationTitle(t("filtros"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(.bibPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("limpar")) { filtro.limpar() }
                        .disabled(filtro.quantosLigados == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("pronto")) { dismiss() }.bold()
                }
            }
        }
    }
}
