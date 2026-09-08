import SwiftUI
import AVFoundation
import AudioToolbox

struct ScannerView: UIViewControllerRepresentable {
    var onScanned: (String) -> Void
    var onDigitarISBN: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.temEntradaManual = (onDigitarISBN != nil)
        vc.onScanned = { codigo in
            onScanned(codigo)
            dismiss()
        }
        vc.onDigitarISBN = {
            dismiss()
            onDigitarISBN?()
        }
        vc.onFechar = { dismiss() }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScanned: ((String) -> Void)?
    var onDigitarISBN: (() -> Void)?
    var onFechar: (() -> Void)?
    var temEntradaManual = false

    private var sessao: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// Tela de aviso em exibicao, para retirar quando a permissao for concedida.
    private weak var avisoEmTela: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        adicionarBotaoCancelar()
        verificarPermissaoEConfigurar()

        // Voltou das Configuracoes: reconsulta e abre a camera se agora pode.
        NotificationCenter.default.addObserver(
            self, selector: #selector(voltouAoPrimeiroPlano),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func voltouAoPrimeiroPlano() {
        guard sessao == nil else { return }
        verificarPermissaoEConfigurar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessao?.stopRunning()
    }

    // MARK: - Permissão

    private func verificarPermissaoEConfigurar() {
        // Estados e textos definidos em `comum/permissoes.md`.
        Task { @MainActor in
            let estado = await Permissoes.garantirCamera()
            if estado.podeUsarCamera {
                avisoEmTela?.removeFromSuperview()
                avisoEmTela = nil
                configurarCamera()
            } else {
                mostrarAviso(estado: estado)
            }
        }
    }

    // MARK: - Setup

    private func configurarCamera() {
        let s = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            mostrarAviso()   // sem camera no aparelho, nao e questao de permissao
            return
        }
        s.addInput(input)

        let output = AVCaptureMetadataOutput()
        s.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .code128]

        let preview = AVCaptureVideoPreviewLayer(session: s)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
        sessao = s

        adicionarMiraDeScanner()

        DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
    }

    private func adicionarBotaoCancelar() {
        let btn = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Cancelar"
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = UIColor.black.withAlphaComponent(0.5)
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        btn.configuration = configuration
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.addTarget(self, action: #selector(cancelar), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func adicionarMiraDeScanner() {
        let overlay = UIView()
        overlay.layer.borderColor = UIColor(red: 0x2b/255, green: 0x5f/255, blue: 0xb3/255, alpha: 1).cgColor
        overlay.layer.borderWidth = 2
        overlay.layer.cornerRadius = 8
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlay.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            overlay.heightAnchor.constraint(equalToConstant: 100)
        ])

        let label = UILabel()
        label.text = "Aponte para o código de barras do livro"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: overlay.bottomAnchor, constant: 16)
        ])
    }

    // MARK: - Aviso (sem câmera / permissão negada)

    private func mostrarAviso(estado: EstadoPermissao? = nil) {
        let permissaoNegada = estado != nil
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 14
        container.alignment = .center
        container.translatesAutoresizingMaskIntoConstraints = false

        let icone = UIImageView(image: UIImage(systemName: permissaoNegada ? "camera.fill.badge.ellipsis" : "camera.slash"))
        icone.tintColor = .white
        icone.contentMode = .scaleAspectFit
        icone.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let titulo = UILabel()
        titulo.text = permissaoNegada ? "Acesso à câmera negado" : "Câmera não disponível"
        titulo.textColor = .white
        titulo.font = .systemFont(ofSize: 20, weight: .semibold)
        titulo.textAlignment = .center
        titulo.numberOfLines = 0

        let msg = UILabel()
        msg.text = switch estado {
        case .restrita:
            "O acesso à câmera está bloqueado neste dispositivo."
        case .some:
            "Para escanear o código de barras, permita o acesso à câmera nas configurações do dispositivo."
        case .none:
            "Este dispositivo não tem câmera (por exemplo, o simulador). Digite o ISBN manualmente."
        }
        msg.textColor = UIColor.white.withAlphaComponent(0.85)
        msg.font = .systemFont(ofSize: 15)
        msg.textAlignment = .center
        msg.numberOfLines = 0

        container.addArrangedSubview(icone)
        container.addArrangedSubview(titulo)
        container.addArrangedSubview(msg)
        container.setCustomSpacing(24, after: msg)

        // Nao adianta oferecer Configuracoes quando a permissao e restrita.
        if estado?.adiantaAbrirConfiguracoes == true {
            container.addArrangedSubview(botao(titulo: "Abrir Configurações", preenchido: true, acao: #selector(abrirAjustes)))
        }
        if temEntradaManual {
            container.addArrangedSubview(botao(titulo: "Digitar ISBN", preenchido: !permissaoNegada, acao: #selector(digitarISBN)))
        }
        container.addArrangedSubview(botao(titulo: "Cancelar", preenchido: false, acao: #selector(cancelar)))

        view.addSubview(container)
        avisoEmTela = container
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func botao(titulo: String, preenchido: Bool, acao: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        var cfg = preenchido ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        cfg.title = titulo
        cfg.baseForegroundColor = .white
        if preenchido {
            cfg.baseBackgroundColor = UIColor(red: 0x2b/255, green: 0x5f/255, blue: 0xb3/255, alpha: 1)
            cfg.cornerStyle = .medium
        }
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24)
        btn.configuration = cfg
        btn.addTarget(self, action: acao, for: .touchUpInside)
        return btn
    }

    @objc private func abrirAjustes() {
        // Nao fecha o scanner: ao voltar, didBecomeActive reconsulta a permissao
        // e abre a camera sozinho, sem obrigar o usuario a navegar de novo.
        Permissoes.abrirConfiguracoes()
    }

    @objc private func digitarISBN() {
        onDigitarISBN?()
    }

    @objc private func cancelar() {
        onFechar?()
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let valor = obj.stringValue else { return }
        sessao?.stopRunning()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScanned?(valor)
    }
}
