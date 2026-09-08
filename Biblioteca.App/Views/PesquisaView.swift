import SwiftUI

struct PesquisaView: View {
    @EnvironmentObject var store: BibliotecaStore
    @State private var busca = ""
    @State private var soComFoto = false

    private var livrosFiltrados: [Livro] {
        var lista = store.livros
        if !busca.isEmpty {
            let termo = normalizar(busca)
            lista = lista.filter { correspondeBusca($0, termo: termo) }
        }
        if soComFoto {
            lista = lista.filter { FotoStore.shared.existe(livroId: $0.fotoId) }
        }
        return lista
    }

    private var contagemTexto: String {
        let n = livrosFiltrados.count
        let filtroAtivo = !busca.isEmpty || soComFoto
        if !filtroAtivo {
            return n == 1 ? "1 livro" : "\(n) livros"
        } else {
            return n == 1 ? "1 livro encontrado" : "\(n) livros encontrados"
        }
    }

    var body: some View {
        List {
            if livrosFiltrados.isEmpty {
                Text(busca.isEmpty && !soComFoto ? "Nenhum livro cadastrado" : "Nenhum resultado")
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
        .searchable(text: $busca, prompt: "Buscar por título, autor, tema, ano ou status")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    soComFoto.toggle()
                } label: {
                    Label("Com foto", systemImage: soComFoto ? "photo.fill" : "photo")
                        .foregroundStyle(soComFoto ? Color.bibAccent : Color.secondary)
                }
            }
        }
    }

    private func correspondeBusca(_ livro: Livro, termo: String) -> Bool {
        contem(livro.titulo, termo)
        || livro.autores.contains { contem($0, termo) }
        || livro.temas.contains { contem($0, termo) }
        || contem(livro.local, termo)
        || contem(livro.ano, termo)
        || correspondeEmprestado(livro, termo: termo)
        || correspondeGrupoLiteratura(livro, termo: termo)
    }

    private func correspondeEmprestado(_ livro: Livro, termo: String) -> Bool {
        if livro.emprestado {
            return contemAlgum(["emprestado", "emprestada", "emprestimo"], termo: termo)
        }
        return contemAlgum(["nao emprestado", "nao emprestada", "disponivel"], termo: termo)
    }

    private func correspondeGrupoLiteratura(_ livro: Livro, termo: String) -> Bool {
        if livro.grupoLiteratura {
            return contemAlgum(["grupo", "literatura", "grupo de literatura"], termo: termo)
        }
        return contemAlgum(["nao grupo", "fora do grupo", "sem grupo"], termo: termo)
    }

    private func contemAlgum(_ opcoes: [String], termo: String) -> Bool {
        opcoes.contains { opcao in
            let texto = normalizar(opcao)
            return texto.contains(termo) || termo.contains(texto)
        }
    }

    private func contem(_ texto: String, _ termo: String) -> Bool {
        normalizar(texto).contains(termo)
    }

    private func normalizar(_ texto: String) -> String {
        texto.lowercased()
             .folding(options: .diacriticInsensitive, locale: .current)
    }
}
