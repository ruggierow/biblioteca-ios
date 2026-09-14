import SwiftUI

struct PesquisaView: View {
    @EnvironmentObject var store: BibliotecaStore
    @ObservedObject private var gruposStore = GruposStore.shared

    @State private var filtro = FiltroPesquisa()
    @State private var mostrandoFiltros = false

    private var livrosFiltrados: [Livro] {
        var lista = store.livros.filter { filtro.aceita($0) }
        let termo = normalizar(filtro.texto)
        if !termo.isEmpty {
            lista = lista.filter { correspondeBusca($0, termo: termo) }
        }
        if filtro.comFoto {
            lista = lista.filter { FotoStore.shared.existe(livroId: $0.fotoId) }
        }
        return lista
    }

    private var contagemTexto: String {
        let n = livrosFiltrados.count
        if !filtro.ativo {
            return n == 1 ? "1 livro" : "\(n) livros"
        } else {
            return n == 1 ? "1 livro encontrado" : "\(n) livros encontrados"
        }
    }

    private var resumoDosFiltros: String {
        filtro.resumo(nomeDoGrupo: gruposStore.nome)
    }

    var body: some View {
        List {
            if !resumoDosFiltros.isEmpty {
                Section {
                    HStack {
                        Text(resumoDosFiltros)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Limpar") { filtro.limpar() }
                            .font(.footnote)
                    }
                }
            }

            if livrosFiltrados.isEmpty {
                Text(filtro.ativo ? "Nenhum resultado" : "Nenhum livro cadastrado")
                    .foregroundColor(.secondary)
            } else {
                Section {
                    ForEach(livrosFiltrados) { livro in
                        NavigationLink(destination: DetalheView(livroId: livro.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(livro.titulo)
                                    .font(.headline)
                                if !livro.autores.filter({ !$0.isEmpty }).isEmpty {
                                    Text(livro.autores.joined(separator: "; "))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                if !livro.temas.filter({ !$0.isEmpty }).isEmpty {
                                    Text(livro.temas.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { livrosFiltrados[$0] }.forEach(store.remover)
                    }
                } header: {
                    Text(contagemTexto).textCase(nil)
                }
            }
        }
        .navigationTitle("Pesquisa")
        .tint(.bibPrimary)
        .searchable(text: $filtro.texto,
                    prompt: "Buscar por título, autor, tema, local ou ano")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mostrandoFiltros = true
                } label: {
                    Label("Filtros", systemImage: filtro.quantosLigados > 0
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(filtro.quantosLigados > 0
                                         ? Color.bibAccent : Color.secondary)
                }
            }
        }
        .sheet(isPresented: $mostrandoFiltros) {
            FiltrosView(filtro: $filtro,
                        grupos: gruposStore.oferecidos(nosLivros: store.livros))
        }
    }

    /// A caixa unica procura nos mesmos campos que as quatro caixas do Mac
    /// (titulo, autor, tema, local) mais o ano. Status e grupo saem daqui:
    /// eles tem seletor proprio na folha de filtros.
    private func correspondeBusca(_ livro: Livro, termo: String) -> Bool {
        contem(livro.titulo, termo)
        || livro.autores.contains { contem($0, termo) }
        || livro.temas.contains { contem($0, termo) }
        || contem(livro.local, termo)
        || contem(livro.ano, termo)
    }

    private func contem(_ texto: String, _ termo: String) -> Bool {
        normalizar(texto).contains(termo)
    }

    private func normalizar(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespaces)
             .lowercased()
             .folding(options: .diacriticInsensitive, locale: .current)
    }
}
