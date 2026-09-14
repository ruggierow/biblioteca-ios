import SwiftUI

struct CadastroView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: BibliotecaStore

    var livroEditando: Livro? = nil
    var isbnInicial: String? = nil

    @State private var titulo = ""
    @State private var autores: [String] = [""]
    @State private var temas: [String] = [""]
    @State private var ano = ""
    @State private var comentarios = ""
    @State private var local = ""
    @State private var emprestado = false
    @State private var gruposSelecionados: Set<Int> = []

    @ObservedObject private var gruposStore = GruposStore.shared

    @State private var isbn = ""
    @State private var isbnStatus = ""
    @State private var isbnStatusCor: Color = .secondary
    @State private var buscandoISBN = false
    @State private var mostrarScanner = false
    @State private var mostrarCampoISBN = false
    @FocusState private var isbnFocado: Bool

    // Foto da capa
    @State private var fotaNova: UIImage? = nil
    @State private var fotoExistente: UIImage? = nil
    @State private var fotoRemovida = false
    @State private var mostrarCamera = false

    var editando: Bool { livroEditando != nil }

    var fotoAtual: UIImage? {
        if fotoRemovida { return nil }
        return fotaNova ?? fotoExistente
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── ISBN ──────────────────────────────────────
                Section {
                    HStack {
                        Button {
                            mostrarCampoISBN.toggle()
                            if mostrarCampoISBN { isbnFocado = true }
                        } label: {
                            Label("Digitar ISBN", systemImage: "character.cursor.ibeam")
                        }
                        .buttonStyle(.borderless)
                        Spacer()
                        Button {
                            mostrarScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                    }

                    if mostrarCampoISBN {
                        HStack {
                            TextField("ISBN (10 ou 13 dígitos)", text: $isbn)
                                .keyboardType(.numberPad)
                                .focused($isbnFocado)
                            Button {
                                Task { await buscarISBN() }
                            } label: {
                                if buscandoISBN {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                            }
                            .disabled(buscandoISBN || isbn.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    if !isbnStatus.isEmpty {
                        Text(isbnStatus)
                            .font(.caption)
                            .foregroundColor(isbnStatusCor)
                    }
                } header: {
                    Text("Buscar por ISBN")
                }

                // ── Foto da capa ───────────────────────────────
                Section("Foto da capa") {
                    if let foto = fotoAtual {
                        VStack(spacing: 12) {
                            Image(uiImage: foto)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                                .frame(maxWidth: .infinity)

                            HStack(spacing: 24) {
                                Button {
                                    mostrarCamera = true
                                } label: {
                                    Label("Trocar", systemImage: "camera")
                                }
                                Button(role: .destructive) {
                                    fotaNova = nil
                                    fotoExistente = nil
                                    fotoRemovida = true
                                } label: {
                                    Label("Remover", systemImage: "trash")
                                }
                            }
                            .font(.callout)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            mostrarCamera = true
                        } label: {
                            Label("Fotografar capa", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                }

                // ── Dados ─────────────────────────────────────
                Section("Dados do livro") {
                    TextField("Título", text: $titulo)
                    SugestoesCadastroView(sugestoes: sugestoesTitulo) { sugestao in
                        titulo = sugestao
                    }
                    TextField("Ano de publicação", text: $ano)
                        .keyboardType(.numberPad)
                    TextField("Local do exemplar", text: $local)
                    SugestoesCadastroView(sugestoes: sugestoesLocal) { sugestao in
                        local = sugestao
                    }
                }

                // ── Autores ───────────────────────────────────
                Section("Autor(es)") {
                    ForEach(autores.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Nome do autor", text: $autores[i])
                                if autores.count > 1 {
                                    Button {
                                        autores.remove(at: i)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.bibDanger)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            SugestoesCadastroView(sugestoes: sugestoesAutores(para: autores[i])) { sugestao in
                                autores[i] = sugestao
                            }
                        }
                    }
                    Button("+ Adicionar autor") { autores.append("") }
                }

                // ── Temas ─────────────────────────────────────
                Section("Tema(s)") {
                    ForEach(temas.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Tema", text: $temas[i])
                                if temas.count > 1 {
                                    Button {
                                        temas.remove(at: i)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.bibDanger)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            SugestoesCadastroView(sugestoes: sugestoesTemas(para: temas[i])) { sugestao in
                                temas[i] = sugestao
                            }
                        }
                    }
                    Button("+ Adicionar tema") { temas.append("") }
                }

                // ── Extras ────────────────────────────────────
                Section("Extras") {
                    Toggle("Emprestado", isOn: $emprestado)
                    TextField("Comentários", text: $comentarios, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Um livro pode estar em mais de um grupo — e assim que o Mac
                // e o Windows guardam, na coluna 8 ("1;3").
                Section("Grupos de literatura") {
                    ForEach(gruposStore.oferecidos(nosLivros: store.livros)) { g in
                        Toggle(g.nome, isOn: Binding(
                            get: { gruposSelecionados.contains(g.id) },
                            set: { ligado in
                                if ligado { gruposSelecionados.insert(g.id) }
                                else { gruposSelecionados.remove(g.id) }
                            }
                        ))
                    }
                }
            }
            .navigationTitle(editando ? "Editar livro" : "Novo livro")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.bibPrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { salvar() }
                        .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $mostrarScanner) {
                ScannerView { codigo in
                    isbn = codigo
                    Task { await buscarISBN() }
                }
            }
            .sheet(isPresented: $mostrarCamera) {
                CapaCameraView { foto in
                    fotaNova = foto
                    fotoRemovida = false
                }
            }
            .onAppear {
                preencherParaEdicao()
                if let isbn0 = isbnInicial, !isbn0.isEmpty, titulo.isEmpty {
                    isbn = isbn0
                    mostrarCampoISBN = true
                    Task { await buscarISBN() }
                }
            }
        }
    }

    // MARK: - Ações

    private func preencherParaEdicao() {
        guard let l = livroEditando else { return }
        titulo         = l.titulo
        autores        = l.autores.isEmpty ? [""] : l.autores
        temas          = l.temas.isEmpty   ? [""] : l.temas
        ano            = l.ano
        comentarios    = l.comentarios
        local          = l.local
        emprestado     = l.emprestado
        gruposSelecionados = Set(l.listaGrupos)
        fotoExistente  = FotoStore.shared.carregar(livroId: l.fotoId)
    }

    private var sugestoesTitulo: [String] {
        sugestoes(em: store.livros.map(\.titulo), para: titulo)
    }

    private var sugestoesLocal: [String] {
        sugestoes(em: store.livros.map(\.local), para: local)
    }

    private func sugestoesAutores(para termo: String) -> [String] {
        sugestoes(em: store.livros.flatMap(\.autores), para: termo)
    }

    private func sugestoesTemas(para termo: String) -> [String] {
        sugestoes(em: store.livros.flatMap(\.temas), para: termo)
    }

    private func sugestoes(em valores: [String], para termo: String) -> [String] {
        let termoLimpo = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard termoLimpo.count >= 2 else { return [] }
        let termoNormalizado = normalizar(termoLimpo)
        var vistos = Set<String>()
        return valores
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { normalizar($0).contains(termoNormalizado) }
            .filter { valor in
                let chave = normalizar(valor)
                guard !vistos.contains(chave) else { return false }
                vistos.insert(chave)
                return normalizar(valor) != termoNormalizado
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .prefix(5)
            .map { $0 }
    }

    private func normalizar(_ texto: String) -> String {
        texto.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    private func salvar() {
        let idAnterior = livroEditando?.fotoId

        var l = livroEditando ?? Livro()
        l.titulo         = titulo.trimmingCharacters(in: .whitespaces)
        l.autores        = autores.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        l.temas          = temas.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        l.ano            = ano.trimmingCharacters(in: .whitespaces)
        l.comentarios    = comentarios
        l.local          = local.trimmingCharacters(in: .whitespaces)
        l.emprestado     = emprestado
        l.listaGrupos    = gruposSelecionados.sorted()

        let idNovo = l.fotoId

        if let novaFoto = fotaNova {
            // Nova foto capturada: salva e remove a antiga se o id mudou
            FotoStore.shared.salvar(novaFoto, livroId: idNovo)
            if let anterior = idAnterior, anterior != idNovo {
                FotoStore.shared.remover(livroId: anterior)
            }
        } else if fotoRemovida {
            // Usuário removeu a foto manualmente
            if let anterior = idAnterior { FotoStore.shared.remover(livroId: anterior) }
            FotoStore.shared.remover(livroId: idNovo)
        } else if let anterior = idAnterior, anterior != idNovo {
            // Título/autores mudaram mas a foto permanece: migra para o novo id
            FotoStore.shared.migrar(de: anterior, para: idNovo)
        }

        if editando { store.atualizar(l) } else { store.adicionar(l) }
        dismiss()
    }

    @MainActor
    private func buscarISBN() async {
        buscandoISBN = true
        isbnStatus = ""
        do {
            if let r = try await ISBNService.buscar(isbn: isbn) {
                if !r.titulo.isEmpty  { titulo = r.titulo }
                if !r.autores.isEmpty { autores = r.autores }
                if !r.temas.isEmpty   { temas = r.temas }
                if !r.ano.isEmpty     { ano = r.ano }
                if !r.comentarios.isEmpty && comentarios.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    comentarios = r.comentarios
                }
                isbnStatus = "Preenchido com sucesso."
                isbnStatusCor = .bibAccent
            } else {
                isbnStatus = "ISBN não encontrado em nenhuma base de dados."
                isbnStatusCor = .red
            }
        } catch ISBNError.invalido {
            isbnStatus = "ISBN inválido (deve ter 10 ou 13 dígitos)."
            isbnStatusCor = .red
        } catch {
            isbnStatus = "Erro ao buscar. Verifique a internet."
            isbnStatusCor = .red
        }
        buscandoISBN = false
    }
}

private struct SugestoesCadastroView: View {
    let sugestoes: [String]
    let selecionar: (String) -> Void

    var body: some View {
        if !sugestoes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sugestoes, id: \.self) { sugestao in
                        Button {
                            selecionar(sugestao)
                        } label: {
                            Text(sugestao)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.bibPrimary.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.bibPrimary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

#Preview("Cadastro novo") {
    CadastroView()
        .environmentObject(BibliotecaStore())
}
