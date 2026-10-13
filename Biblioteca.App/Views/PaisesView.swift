import SwiftUI

/// A tabela do acervo por país.
///
/// POR QUE TABELA E NÃO MAPA: decisão do usuário em 12/10/2026 — "no iPhone e no
/// Android faça por tabela e não por mapa". Mapa clicável com quase quarenta
/// países num polegar não funciona; no Mac e no Windows, onde há mouse e tela
/// larga, o mapa existe.
///
/// Tocar numa linha abre a Pesquisa já filtrada por aquele país.
struct PaisesView: View {
    @EnvironmentObject var store: BibliotecaStore

    private var contagem: [(iso: String, total: Int)] {
        var c: [String: Int] = [:]
        for l in store.livros {
            let iso = l.pais.trimmingCharacters(in: .whitespaces).uppercased()
            if !iso.isEmpty { c[iso, default: 0] += 1 }
        }
        return c.map { (iso: $0.key, total: $0.value) }
            .sorted { $0.total != $1.total ? $0.total > $1.total
                                           : Paises.nome($0.iso) < Paises.nome($1.iso) }
    }

    var body: some View {
        let paises = contagem
        let comPais = paises.reduce(0) { $0 + $1.total }
        let semPais = store.livros.count - comPais
        let maior = max(1, paises.first?.total ?? 1)

        List {
            Section {
                if paises.isEmpty {
                    Text("O país vem do tema do livro ou do ISBN. "
                         + "Leia o código de barras de um livro para começar.")
                        .foregroundColor(.secondary)
                        .font(.callout)
                } else {
                    ForEach(paises, id: \.iso) { p in
                        NavigationLink(destination: PesquisaView(paisInicial: p.iso)) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(Paises.nome(p.iso)).fontWeight(.semibold)
                                    Spacer()
                                    Text("\(p.total)")
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                ProgressView(value: Double(p.total), total: Double(maior))
                                    .tint(.bibAccent)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } footer: {
                if !paises.isEmpty {
                    Text("\(comPais) \(comPais == 1 ? "livro" : "livros") em "
                         + "\(paises.count) \(paises.count == 1 ? "país" : "países")"
                         + (semPais > 0 ? " · \(semPais) ainda sem país" : ""))
                }
            }
        }
        .navigationTitle("Países")
    }
}
