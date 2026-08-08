import Foundation

struct Livro: Identifiable {
    var id = UUID()
    var titulo: String = ""
    var autores: [String] = [""]
    var temas: [String] = [""]
    var ano: String = ""
    var emprestado: Bool = false
    var comentarios: String = ""
    var local: String = ""
    var grupoLiteratura: Bool = false
}
