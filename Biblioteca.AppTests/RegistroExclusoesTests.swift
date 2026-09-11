import Foundation
import Testing
@testable import Biblioteca_App

/// Testes do registro de exclusões de capas.
///
/// O defeito que motivou tudo isto (10/09/2026): quatro capas órfãs foram
/// apagadas no Mac, e voltaram na sincronização seguinte do iPhone — que ainda
/// as tinha em `Documents/capas/` e as mesclava de volta no `biblioteca.dat`.
/// Mesclagem só sabe somar. Ver `comum/exclusao-de-fotos.md`.
struct RegistroExclusoesTests {

    // MARK: - A regra central

    @Test("capa sem exclusão pendente é mantida")
    func semExclusao() {
        #expect(RegistroExclusoes.destino(fotoId: "capa1",
                                          modificadaEm: Date(),
                                          registro: [:]) == .manter)
    }

    @Test("capa apagada em outro aparelho é removida daqui também")
    func apagadaEmOutroAparelho() {
        let apagadaEm = Date()
        let fotoAntiga = apagadaEm.addingTimeInterval(-3600)   // 1 h antes
        #expect(RegistroExclusoes.destino(fotoId: "fantasma",
                                          modificadaEm: fotoAntiga,
                                          registro: ["fantasma": apagadaEm]) == .apagar)
    }

    @Test("refotografar depois de apagar supera a exclusão")
    func refotografada() {
        let apagadaEm = Date()
        let fotoNova = apagadaEm.addingTimeInterval(3600)      // 1 h depois
        #expect(RegistroExclusoes.destino(fotoId: "capa1",
                                          modificadaEm: fotoNova,
                                          registro: ["capa1": apagadaEm]) == .exclusaoSuperada)
    }

    @Test("o registro só afeta o fotoId registrado")
    func naoAfetaOutras() {
        let reg = ["fantasma": Date()]
        #expect(RegistroExclusoes.destino(fotoId: "capa1",
                                          modificadaEm: .distantPast,
                                          registro: reg) == .manter)
    }

    // MARK: - Ida e volta em disco

    @Test("registrar, ler e esquecer")
    func idaEVolta() throws {
        let pasta = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }

        #expect(RegistroExclusoes.ler(naPasta: pasta).isEmpty)

        RegistroExclusoes.registrar(["a", "b"], naPasta: pasta)
        let lido = RegistroExclusoes.ler(naPasta: pasta)
        #expect(lido.count == 2)
        #expect(lido["a"] != nil)

        RegistroExclusoes.esquecer(["a"], naPasta: pasta)
        let depois = RegistroExclusoes.ler(naPasta: pasta)
        #expect(depois.count == 1)
        #expect(depois["a"] == nil)
        #expect(depois["b"] != nil)
    }

    @Test("entradas vencidas são descartadas na leitura")
    func vencidas() throws {
        let pasta = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }

        // Uma entrada de 200 dias atrás e outra de ontem.
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let velha = f.string(from: Date().addingTimeInterval(-200 * 86_400))
        let nova  = f.string(from: Date().addingTimeInterval(-86_400))
        let json = ["antiga": velha, "recente": nova]
        let dados = try JSONSerialization.data(withJSONObject: json)
        try dados.write(to: pasta.appendingPathComponent("biblioteca-removidas.json"))

        let lido = RegistroExclusoes.ler(naPasta: pasta)
        #expect(lido["antiga"] == nil, "além de \(RegistroExclusoes.validadeEmDias) dias a entrada sai")
        #expect(lido["recente"] != nil)
    }

    @Test("pasta nula não quebra nada")
    func pastaNula() {
        #expect(RegistroExclusoes.ler(naPasta: nil).isEmpty)
        RegistroExclusoes.registrar(["x"], naPasta: nil)   // não deve lançar
    }
}
