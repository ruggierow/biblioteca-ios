import SwiftUI

@main
struct Biblioteca_AppApp: App {
    @StateObject private var store = BibliotecaStore()
    @StateObject private var idioma = Idioma()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(idioma)
                // O `.id` é o que faz a troca de idioma alcançar a tela
                // inteira. Observar o objeto não bastaria: no SwiftUI só é
                // redesenhada a `View` que DECLARA o que mudou, e nenhuma das
                // telas declara o idioma — elas só chamam `t()`. Trocar o
                // `id` destrói e recria a subárvore, e aí todas trocam juntas.
                // O preço é voltar à tela inicial, que é onde o seletor está.
                .id(idioma.atual)
                .task { idioma.carregar() }
                .onChange(of: scenePhase) { _, fase in
                    if fase == .active { store.recarregarArquivo() }
                }
        }
    }
}
