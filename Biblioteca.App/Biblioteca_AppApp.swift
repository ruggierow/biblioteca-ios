import SwiftUI

@main
struct Biblioteca_AppApp: App {
    @StateObject private var store = BibliotecaStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, fase in
                    if fase == .active { store.recarregarArquivo() }
                }
        }
    }
}
