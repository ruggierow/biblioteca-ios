import SwiftUI
import UniformTypeIdentifiers

/// O fluxo de "Selecionar pasta" — o mesmo das quatro plataformas.
///
/// Mora num arquivo só porque DOIS lugares o usam: a linha nova da tela
/// inicial e o "Trocar pasta" da Sincronização. Duplicá-lo recriaria o
/// problema que esta mudança existe para resolver — dois caminhos para a
/// mesma coisa, divergindo com o tempo.
///
/// Os quatro ramos, e a razão de cada um:
///
///  A. a pasta TEM biblioteca.txt  → mostra quantos livros achou e confirma.
///     Perguntar "quer usar o arquivo?" sem dizer o que há dentro é pedir um
///     palpite; com a contagem, é uma pergunta respondível.
///  B. a pasta está VAZIA          → cria e avisa, sem perguntar. O usuário
///     acabou de escolher aquela pasta com essa finalidade.
///  C. tem arquivo e não leu       → diz o que houve e oferece outra pasta.
///     NUNCA cria por cima: pode ser a biblioteca de alguém, ilegível por
///     permissão ou ainda baixando do iCloud.
///  D. vazia, mas há livros abertos → pergunta. É o único caso com algo a
///     perder, e a resposta muda o que vai para o disco.
struct FluxoSelecionarPasta: ViewModifier {
    @Binding var mostrarSeletor: Bool
    @EnvironmentObject var store: BibliotecaStore

    @State private var achou: ConteudoDaPasta?
    @State private var naoLeu: ConteudoDaPasta?
    @State private var vaziaComLivros: ConteudoDaPasta?
    @State private var aviso: String?

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $mostrarSeletor,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { resultado in
                guard case .success(let urls) = resultado,
                      let pasta = urls.first else { return } // cancelou
                decidir(store.olharPasta(pasta))
            }

            // C — há arquivo e não deu para ler.
            .alert(t("naoConsegueLerTitulo"),
                   isPresented: binding($naoLeu),
                   presenting: naoLeu) { _ in
                Button(t("escolherOutraPasta")) { mostrarSeletor = true }
                Button(t("cancelar"), role: .cancel) {}
            } message: { c in
                Text(t("naoConsegueLer", [c.erroDeLeitura ?? ""]))
            }

            // A — achou: a contagem faz a pergunta ser respondível.
            .alert(t("achouBiblioteca"),
                   isPresented: binding($achou),
                   presenting: achou) { c in
                Button(t("usarEstaBiblioteca")) { store.vincularPasta(c.pasta) }
                Button(t("escolherOutraPasta")) { mostrarSeletor = true }
                Button(t("cancelar"), role: .cancel) {}
            } message: { c in
                Text(t("achouBibliotecaCorpo", [c.nome, c.livros]))
            }

            // D — vazia com livros abertos.
            .alert(t("pastaVaziaComLivros", [store.livros.count]),
                   isPresented: binding($vaziaComLivros),
                   presenting: vaziaComLivros) { c in
                Button(t("levarParaPasta", [store.livros.count])) {
                    criar(c, levarLivros: true)
                }
                Button(t("comecarVazia")) { criar(c, levarLivros: false) }
                Button(t("cancelar"), role: .cancel) {}
            }

            .alert(t("criouArquivo", [aviso ?? ""]),
                   isPresented: binding($aviso),
                   presenting: aviso) { _ in
                Button("OK", role: .cancel) {}
            }
    }

    private func decidir(_ c: ConteudoDaPasta) {
        if c.erroDeLeitura != nil {
            naoLeu = c
        } else if c.temArquivo {
            achou = c
        } else if store.livros.isEmpty {
            criar(c, levarLivros: false) // B: nada a perder, nada a perguntar
        } else {
            vaziaComLivros = c // D
        }
    }

    private func criar(_ c: ConteudoDaPasta, levarLivros: Bool) {
        store.criarNaPasta(c.pasta, levarLivros: levarLivros)
        if store.erroMensagem == nil { aviso = c.nome }
    }

    /// `isPresented` a partir de um opcional: some quando o alerta fecha.
    private func binding<T>(_ estado: Binding<T?>) -> Binding<Bool> {
        Binding(get: { estado.wrappedValue != nil },
                set: { if !$0 { estado.wrappedValue = nil } })
    }
}

extension View {
    /// Põe o fluxo de "Selecionar pasta" nesta tela.
    func fluxoSelecionarPasta(mostrando seletor: Binding<Bool>) -> some View {
        modifier(FluxoSelecionarPasta(mostrarSeletor: seletor))
    }
}
