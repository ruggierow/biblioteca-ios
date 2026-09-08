import AVFoundation
import UIKit

/// Estado da permissão de câmera. Os quatro casos de `comum/permissoes.md`.
enum EstadoPermissao {
    case concedida
    case naoPerguntada
    case negada
    /// Bloqueada por controle parental ou política de dispositivo — pedir não adianta.
    case restrita

    var podeUsarCamera: Bool { self == .concedida }

    /// Só faz sentido oferecer "Abrir Configurações" se o usuário puder mudar.
    var adiantaAbrirConfiguracoes: Bool { self == .negada }
}

/// Ponto único de consulta e pedido de permissão de câmera no app iOS.
///
/// Existe para que o scanner de ISBN e a captura de capa se comportem igual —
/// antes, a captura de capa falhava em silêncio e deixava a tela preta.
/// O comportamento está especificado em `comum/permissoes.md`.
enum Permissoes {

    static func estadoDaCamera() -> EstadoPermissao {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    return .concedida
        case .notDetermined: return .naoPerguntada
        case .restricted:    return .restrita
        case .denied:        return .negada
        @unknown default:    return .negada
        }
    }

    /// Consulta o estado e, se o usuário nunca foi perguntado, pergunta.
    /// Retorna o estado final — nunca deixa em `.naoPerguntada`.
    static func garantirCamera() async -> EstadoPermissao {
        let atual = estadoDaCamera()
        guard atual == .naoPerguntada else { return atual }
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return estadoDaCamera()
    }

    @MainActor
    static func abrirConfiguracoes() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
