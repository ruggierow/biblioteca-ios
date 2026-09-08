import SwiftUI

/// Para que serve a câmera na tela que pediu a permissão.
/// Muda o texto explicativo e se existe alternativa sem câmera.
enum UsoDaCamera {
    case scanner
    case capa

    var explicacao: String {
        switch self {
        case .scanner:
            return "Para escanear o código de barras, permita o acesso à câmera nas configurações do dispositivo."
        case .capa:
            return "Para fotografar a capa, permita o acesso à câmera nas configurações do dispositivo."
        }
    }
}

/// Tela exibida quando a câmera está negada ou restrita.
/// Mesma aparência e mesmos textos no scanner e na captura de capa —
/// e o equivalente em Flutter é `lib/views/permissao_negada_view.dart`.
/// Especificação: `comum/permissoes.md`.
struct PermissaoNegadaView: View {
    let uso: UsoDaCamera
    let estado: EstadoPermissao
    /// Só o scanner tem alternativa sem câmera.
    var onDigitarISBN: (() -> Void)? = nil
    var onCancelar: () -> Void

    private var explicacao: String {
        estado == .restrita
            ? "O acesso à câmera está bloqueado neste dispositivo."
            : uso.explicacao
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "camera.fill.badge.ellipsis")
                    .font(.system(size: 62))
                    .foregroundStyle(.white.opacity(0.55))

                Text("Acesso à câmera negado")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                Text(explicacao)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                VStack(spacing: 12) {
                    if estado.adiantaAbrirConfiguracoes {
                        Button {
                            Permissoes.abrirConfiguracoes()
                        } label: {
                            Label("Abrir Configurações", systemImage: "gearshape")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .background(Color.bibPrimary, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                    }

                    if let onDigitarISBN {
                        Button("Digitar ISBN", action: onDigitarISBN)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }

                    Button("Cancelar", action: onCancelar)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 2)
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, 32)
        }
    }
}
