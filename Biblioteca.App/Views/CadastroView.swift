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
    @State private var grupoLiteratura = false

    @State private var isbn = ""
    @State private var isbnStatus = ""
    @State private var isbnStatusCor: Color = .secondary
    @State private var buscandoISBN = false
    @State private var mostrarScanner = false

    var editando: Bool { livroEditando != nil }

    var body: some View {
        NavigationStack {
            Form {
                // ── ISBN ──────────────────────────────────────
                Section {
                    HStack {
                        TextField("ISBN (10 ou 13 dígitos)", text: $isbn)
                            .keyboardType(.numberPad)
                        Button {
                            mostrarScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2)
                        }
                    }
                    Button {
                        Task { await buscarISBN() }
                    } label: {
                        if buscandoISBN {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Buscando…")
                            }
                        } else {
                            Label("Buscar ISBN", systemImage: "magnifyingglass")
                        }
                    }
                    .disabled(buscandoISBN || isbn.trimmingCharacters(in: .whitespaces).isEmpty)

                    if !isbnStatus.isEmpty {
                        Text(isbnStatus)
                            .font(.caption)
                            .foregroundColor(isbnStatusCor)
                    }
                } header: {
                    Text("Buscar por ISBN")
                }

                // ── Dados ─────────────────────────────────────
                Section("Dados do livro") {
                    TextField("Título", text: $titulo)
                    TextField("Ano de publicação", text: $ano)
                        .keyboardType(.numberPad)
                    TextField("Local do exemplar", text: $local)
                }

                // ── Autores ───────────────────────────────────
                Section("Autor(es)") {
                    ForEach(autores.indices, id: \.self) { i in
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
                    }
                    Button("+ Adicionar autor") { autores.append("") }
                }

                // ── Temas ─────────────────────────────────────
                Section("Tema(s)") {
                    ForEach(temas.indices, id: \.self) { i in
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
                    }
                    Button("+ Adicionar tema") { temas.append("") }
                }

                // ── Extras ────────────────────────────────────
                Section("Extras") {
                    Toggle("Emprestado", isOn: $emprestado)
                    Toggle("Grupo de literatura", isOn: $grupoLiteratura)
                    TextField("Comentários", text: $comentarios, axis: .vertical)
                        .lineLimit(3...6)
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
            .onAppear {
                preencherParaEdicao()
                if let isbn0 = isbnInicial, !isbn0.isEmpty, titulo.isEmpty {
                    isbn = isbn0
                    Task { await buscarISBN() }
                }
            }
        }
    }

    // MARK: - Ações

    private func preencherParaEdicao() {
        guard let l = livroEditando else { return }
        titulo = l.titulo
        autores = l.autores.isEmpty ? [""] : l.autores
        temas = l.temas.isEmpty ? [""] : l.temas
        ano = l.ano
        comentarios = l.comentarios
        local = l.local
        emprestado = l.emprestado
        grupoLiteratura = l.grupoLiteratura
    }

    private func salvar() {
        var l = livroEditando ?? Livro()
        l.titulo = titulo.trimmingCharacters(in: .whitespaces)
        l.autores = autores.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        l.temas = temas.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        l.ano = ano.trimmingCharacters(in: .whitespaces)
        l.comentarios = comentarios
        l.local = local.trimmingCharacters(in: .whitespaces)
        l.emprestado = emprestado
        l.grupoLiteratura = grupoLiteratura
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
