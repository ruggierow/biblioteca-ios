import SwiftUI
import AVFoundation
import Vision
import Combine

// MARK: - Formato de capa (preset)

enum FormatoCapa: CaseIterable, Equatable {
    case retrato    // 2:3  — romances, técnicos, etc.
    case quadrado   // 1:1  — alguns livros de arte e catálogos
    case largo      // 4:3  — álbuns, mesas de café, atlas

    var rotulo: String {
        switch self {
        case .retrato:  return "2:3"
        case .quadrado: return "1:1"
        case .largo:    return "4:3"
        }
    }

    var descricao: String {
        switch self {
        case .retrato:  return "Livro padrão"
        case .quadrado: return "Arte / catálogo"
        case .largo:    return "Álbum / atlas"
        }
    }

    var aspecto: CGFloat {
        switch self {
        case .retrato:  return 2.0 / 3.0
        case .quadrado: return 1.0
        case .largo:    return 4.0 / 3.0
        }
    }
}

// MARK: - Canto do retângulo-guia

enum CantoGuia: CaseIterable, Hashable {
    case topLeft, topRight, bottomLeft, bottomRight

    func posicao(em rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:     return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:    return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:  return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

// MARK: - View principal

struct CapaCameraView: View {
    var onCapturar: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var modelo = CapaCameraModelo()

    /// Nulo enquanto a permissão ainda não foi consultada.
    @State private var permissao: EstadoPermissao? = nil

    @State private var guia: CGRect = .zero
    @State private var camSize: CGSize = .zero
    @State private var prevCenterTrans: CGSize = .zero
    @State private var prevCornerTrans: CGSize = .zero

    /// Foto processada aguardando confirmação do usuário.
    @State private var fotaPrevia: UIImage? = nil
    /// "Vision" se detectada automaticamente, "Guia" se recorte manual.
    @State private var origemPrevia = ""

    var body: some View {
        ZStack {
            if let permissao, !permissao.podeUsarCamera {
                PermissaoNegadaView(
                    uso: .capa,
                    estado: permissao,
                    onCancelar: { dismiss() }
                )
            } else {
                cameraUI

                if let foto = fotaPrevia {
                    ConfirmacaoCapaView(
                        foto: foto,
                        deteccaoAutomatica: origemPrevia == "Vision",
                        onUsar: { onCapturar(foto); dismiss() },
                        onRefazer: { fotaPrevia = nil }
                    )
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: fotaPrevia != nil)
        .task { await verificarPermissao() }
        // Voltou das Configurações: reconsulta e abre a câmera se agora pode.
        .onChange(of: scenePhase) { _, nova in
            if nova == .active { Task { await verificarPermissao() } }
        }
        .onDisappear { modelo.parar() }
    }

    /// Consulta — e pede, na primeira vez — a permissão de câmera, e só liga a
    /// sessão quando concedida. Antes daqui a tela simplesmente ficava preta.
    /// Comportamento especificado em `comum/permissoes.md`.
    private func verificarPermissao() async {
        guard permissao?.podeUsarCamera != true else { return }
        let estado = await Permissoes.garantirCamera()
        permissao = estado
        guard estado.podeUsarCamera else { return }

        modelo.onPrevia = { foto, origem in
            fotaPrevia = foto
            origemPrevia = origem
        }
        modelo.iniciar()
    }

    // MARK: - UI da câmera

    @ViewBuilder
    private var cameraUI: some View {
        VStack(spacing: 0) {

            // ── Barra superior ─────────────────────────────
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.5), in: Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Spacer()
                if guia != .zero {
                    Text(rotuloAspecto(guia))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                }
            }
            .background(.black)

            // ── Área da câmera com guia ajustável ─────────
            ZStack {
                Color.black
                CameraPreviewView(session: modelo.session)

                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            guard guia == .zero else { return }
                            camSize = geo.size
                            guia = presetGuia(em: geo.size, aspecto: FormatoCapa.retrato.aspecto)
                        }

                    if guia != .zero {
                        CapaOverlayView(guia: guia)

                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            .frame(width: guia.width, height: guia.height)
                            .position(x: guia.midX, y: guia.midY)

                        CantosGuiaView(guia: guia)

                        // Instrução: incentiva enquadre com folga para Vision funcionar melhor
                        Text("Enquadre a capa com uma folga nas bordas")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.5), in: Capsule())
                            .position(x: geo.size.width / 2,
                                      y: max(guia.minY - 28, 18))

                        // Handle central: move o retângulo inteiro
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                            .position(x: guia.midX, y: guia.midY)
                            .gesture(gestoMover(camSize: geo.size))

                        // Handles nos 4 cantos
                        ForEach(CantoGuia.allCases, id: \.self) { c in
                            handleCanto(c, camSize: geo.size)
                        }
                    }
                }
            }
            .layoutPriority(1)
            .clipped()

            // ── Controles inferiores ───────────────────────
            VStack(spacing: 8) {
                Text("Reajustar proporção")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 10) {
                    ForEach(FormatoCapa.allCases, id: \.rotulo) { f in
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                if camSize != .zero {
                                    guia = presetGuia(em: camSize, aspecto: f.aspecto)
                                }
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(f.rotulo).font(.caption.weight(.semibold))
                                Text(f.descricao).font(.caption2).opacity(0.75)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.white.opacity(0.2), in: Capsule())
                            .foregroundStyle(Color.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(f.descricao)
                    }
                }

                Button {
                    modelo.guia = guia
                    modelo.camSize = camSize
                    modelo.capturar()
                } label: {
                    ZStack {
                        Circle().fill(.white).frame(width: 68)
                        Circle().strokeBorder(.white, lineWidth: 3).frame(width: 84)
                    }
                }
                .disabled(modelo.processando || !modelo.pronto || guia == .zero)
                .padding(.top, 4)

                if modelo.processando {
                    VStack(spacing: 4) {
                        ProgressView().tint(.white)
                        Text("Detectando bordas…")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, minHeight: 190)
            .background(.black)
        }
        .background(.black)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Handles de canto (área de toque 48pt, visual 24pt)

    @ViewBuilder
    private func handleCanto(_ canto: CantoGuia, camSize: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: 48, height: 48)
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 4)
        }
        .position(canto.posicao(em: guia))
        .gesture(gestoCanto(canto, camSize: camSize))
    }

    private func gestoCanto(_ canto: CantoGuia, camSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let dx = v.translation.width  - prevCornerTrans.width
                let dy = v.translation.height - prevCornerTrans.height
                prevCornerTrans = v.translation
                let minSz: CGFloat = 60
                var g = guia
                switch canto {
                case .topLeft:
                    let nx = max(0, min(g.minX + dx, g.maxX - minSz))
                    let ny = max(0, min(g.minY + dy, g.maxY - minSz))
                    g = CGRect(x: nx, y: ny, width: g.maxX - nx, height: g.maxY - ny)
                case .topRight:
                    let ny = max(0, min(g.minY + dy, g.maxY - minSz))
                    let nr = min(camSize.width,  max(g.minX + minSz, g.maxX + dx))
                    g = CGRect(x: g.minX, y: ny, width: nr - g.minX, height: g.maxY - ny)
                case .bottomLeft:
                    let nx = max(0, min(g.minX + dx, g.maxX - minSz))
                    let nb = min(camSize.height, max(g.minY + minSz, g.maxY + dy))
                    g = CGRect(x: nx, y: g.minY, width: g.maxX - nx, height: nb - g.minY)
                case .bottomRight:
                    let nr = min(camSize.width,  max(g.minX + minSz, g.maxX + dx))
                    let nb = min(camSize.height, max(g.minY + minSz, g.maxY + dy))
                    g = CGRect(x: g.minX, y: g.minY, width: nr - g.minX, height: nb - g.minY)
                }
                guia = g
            }
            .onEnded { _ in prevCornerTrans = .zero }
    }

    private func gestoMover(camSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let dx = v.translation.width  - prevCenterTrans.width
                let dy = v.translation.height - prevCenterTrans.height
                prevCenterTrans = v.translation
                let nx = max(0, min(guia.minX + dx, camSize.width  - guia.width))
                let ny = max(0, min(guia.minY + dy, camSize.height - guia.height))
                guia = CGRect(origin: CGPoint(x: nx, y: ny), size: guia.size)
            }
            .onEnded { _ in prevCenterTrans = .zero }
    }

    // MARK: - Helpers

    private func presetGuia(em size: CGSize, aspecto: CGFloat) -> CGRect {
        let mH: CGFloat = 32, mV: CGFloat = 44
        let maxW = size.width  - mH * 2
        let maxH = size.height - mV * 2
        var gW, gH: CGFloat
        if aspecto < 1 {
            gW = maxW * 0.80; gH = gW / aspecto
            if gH > maxH { gH = maxH; gW = gH * aspecto }
        } else if aspecto == 1 {
            let l = min(maxW * 0.78, maxH * 0.88); gW = l; gH = l
        } else {
            gW = maxW * 0.90; gH = gW / aspecto
            if gH > maxH { gH = maxH * 0.88; gW = gH * aspecto }
        }
        return CGRect(x: (size.width  - gW) / 2,
                      y: (size.height - gH) / 2,
                      width: gW, height: gH)
    }

    private func rotuloAspecto(_ r: CGRect) -> String {
        guard r.height > 0 else { return "" }
        let w = Int(r.width.rounded()), h = Int(r.height.rounded())
        let d = mdc(w, h)
        return "\(w / d):\(h / d)"
    }

    private func mdc(_ a: Int, _ b: Int) -> Int { b == 0 ? max(1, a) : mdc(b, a % b) }
}

// MARK: - Tela de confirmação pós-captura

private struct ConfirmacaoCapaView: View {
    let foto: UIImage
    let deteccaoAutomatica: Bool
    let onUsar: () -> Void
    let onRefazer: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(uiImage: foto)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(8)
                    .padding(.horizontal, 40)
                    .shadow(color: .white.opacity(0.08), radius: 24)

                Spacer().frame(height: 20)

                Label(
                    deteccaoAutomatica
                        ? "Borda detectada automaticamente"
                        : "Recorte pelo guia",
                    systemImage: deteccaoAutomatica ? "sparkles" : "crop"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

                Spacer()

                HStack(spacing: 16) {
                    Button(action: onRefazer) {
                        Label("Refazer", systemImage: "arrow.counterclockwise")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.white.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }

                    Button(action: onUsar) {
                        Label("Usar capa", systemImage: "checkmark")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.black)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Sobreposição com abertura transparente

private struct CapaOverlayView: View {
    let guia: CGRect

    var body: some View {
        Color.black.opacity(0.55)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .frame(width: guia.width, height: guia.height)
                    .position(x: guia.midX, y: guia.midY)
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
    }
}

// MARK: - Marcadores de canto estilo visor

private struct CantosGuiaView: View {
    let guia: CGRect
    private let brac: CGFloat = 22
    private let esp: CGFloat  = 2.5

    var body: some View {
        Canvas { ctx, _ in
            let cantos: [(CGPoint, CGFloat, CGFloat)] = [
                (CGPoint(x: guia.minX, y: guia.minY),  1,  1),
                (CGPoint(x: guia.maxX, y: guia.minY), -1,  1),
                (CGPoint(x: guia.minX, y: guia.maxY),  1, -1),
                (CGPoint(x: guia.maxX, y: guia.maxY), -1, -1),
            ]
            let estilo = StrokeStyle(lineWidth: esp, lineCap: .round)
            for (p, dx, dy) in cantos {
                var ph = Path(); ph.move(to: p)
                ph.addLine(to: CGPoint(x: p.x + dx * brac, y: p.y))
                var pv = Path(); pv.move(to: p)
                pv.addLine(to: CGPoint(x: p.x, y: p.y + dy * brac))
                ctx.stroke(ph, with: .color(.white), style: estilo)
                ctx.stroke(pv, with: .color(.white), style: estilo)
            }
        }
    }
}

// MARK: - Pré-visualização da câmera (ponte UIKit)

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> _CapaPreviewUIView {
        let v = _CapaPreviewUIView(); v.session = session; return v
    }
    func updateUIView(_ uiView: _CapaPreviewUIView, context: Context) {}
}

final class _CapaPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var session: AVCaptureSession? {
        didSet { previewLayer.session = session; previewLayer.videoGravity = .resizeAspectFill }
    }
}

// MARK: - Modelo da câmera
// Sem @MainActor na classe para evitar conflito com ObservableObject + @Published.

final class CapaCameraModelo: NSObject, ObservableObject {
    @Published var processando = false
    @Published var pronto = false

    var guia: CGRect = .zero
    var camSize: CGSize = .zero
    /// Chamado com (foto processada, "Vision" | "Guia") após captura e detecção.
    var onPrevia: ((UIImage, String) -> Void)?

    let session = AVCaptureSession()
    private let fotoOutput = AVCapturePhotoOutput()
    private var configurado = false

    func iniciar() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.configurarSessao()
            if !self.session.isRunning { self.session.startRunning() }
            await MainActor.run { self.pronto = true }
        }
    }

    func parar() {
        Task.detached(priority: .background) { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capturar() {
        guard pronto, !processando else { return }
        processando = true
        fotoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    private func configurarSessao() async {
        guard !configurado else { return }
        configurado = true
        // A permissão já foi resolvida pela view em verificarPermissao().
        guard Permissoes.estadoDaCamera().podeUsarCamera else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { session.commitConfiguration(); return }
        session.addInput(input)
        if session.canAddOutput(fotoOutput) { session.addOutput(fotoOutput) }
        session.commitConfiguration()
    }
}

// MARK: - Delegado de captura + detecção Vision

extension CapaCameraModelo: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { Task { @MainActor [weak self] in self?.processando = false } }
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let raw  = UIImage(data: data) else { return }

        let orientada = normalizar(raw)

        // Tenta detectar a borda exata da capa com o framework Vision.
        if let visionImg = detectarCapaVision(em: orientada) {
            let final = redimensionar(visionImg, maxPx: 900)
            Task { @MainActor [weak self] in self?.onPrevia?(final, "Vision") }
        } else {
            // Fallback: recorte pela posição do guia no preview.
            let guiaAlvo    = guia
            let camSizeAlvo = camSize
            let cortada = (!guiaAlvo.isEmpty && camSizeAlvo != .zero)
                ? cortarExato(orientada, guia: guiaAlvo, camSize: camSizeAlvo)
                : orientada
            let final = redimensionar(cortada, maxPx: 900)
            Task { @MainActor [weak self] in self?.onPrevia?(final, "Guia") }
        }
    }

    // MARK: - Detecção Vision + correção de perspectiva

    /// Detecta o retângulo dominante na imagem (a capa do livro) e aplica correção
    /// de perspectiva usando os 4 cantos reais — igual ao scanner de documentos do iOS.
    /// Retorna nil se a detecção falhar (confiança baixa ou nenhum retângulo encontrado).
    private func detectarCapaVision(em img: UIImage) -> UIImage? {
        guard let cgImage = img.cgImage else { return nil }

        let request = VNDetectRectanglesRequest()
        request.minimumConfidence   = 0.6   // confiança mínima da detecção
        request.minimumAspectRatio  = 0.25  // permite livros finos (1:4)
        request.maximumAspectRatio  = 1.0   // até quadrado / paisagem
        request.minimumSize         = 0.15  // a capa deve ocupar ≥ 15% da imagem
        request.maximumObservations = 1     // queremos só o retângulo com maior confiança

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil,
              let obs = request.results?.first,
              obs.confidence >= 0.6 else { return nil }

        return corrigirPerspectiva(cgImage: cgImage, scale: img.scale, obs: obs)
    }

    /// Aplica CIPerspectiveCorrection usando os 4 cantos detectados pelo Vision.
    /// Vision e CIImage compartilham o mesmo sistema de coordenadas (origem inferior-esquerda,
    /// y cresce para cima), então basta multiplicar pelos pixels da imagem.
    private func corrigirPerspectiva(cgImage: CGImage,
                                     scale: CGFloat,
                                     obs: VNRectangleObservation) -> UIImage? {
        let W = CGFloat(cgImage.width)
        let H = CGFloat(cgImage.height)

        // Converte coordenadas Vision normalizadas → pixels CIImage (mesma orientação de eixos)
        func pt(_ p: CGPoint) -> CIVector {
            CIVector(x: p.x * W, y: p.y * H)
        }

        let ciImage = CIImage(cgImage: cgImage)

        guard let filtro = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filtro.setValue(ciImage,             forKey: kCIInputImageKey)
        filtro.setValue(pt(obs.topLeft),     forKey: "inputTopLeft")
        filtro.setValue(pt(obs.topRight),    forKey: "inputTopRight")
        filtro.setValue(pt(obs.bottomLeft),  forKey: "inputBottomLeft")
        filtro.setValue(pt(obs.bottomRight), forKey: "inputBottomRight")

        guard let saida = filtro.outputImage else { return nil }

        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgSaida = ctx.createCGImage(saida, from: saida.extent) else { return nil }

        return UIImage(cgImage: cgSaida, scale: scale, orientation: .up)
    }

    // MARK: - Processamento de imagem

    /// Recorta a foto exatamente na região do guia, mapeando coordenadas do
    /// preview (aspectFill) para pixels reais da foto capturada.
    private func cortarExato(_ img: UIImage, guia: CGRect, camSize: CGSize) -> UIImage {
        let fW = img.size.width
        let fH = img.size.height
        let s  = max(camSize.width / fW, camSize.height / fH)   // escala aspectFill

        let overX = (fW * s - camSize.width)  / 2 / s
        let overY = (fH * s - camSize.height) / 2 / s

        let cropX = overX + guia.minX / s
        let cropY = overY + guia.minY / s
        let cropW = guia.width  / s
        let cropH = guia.height / s

        let sc     = img.scale
        let cropPx = CGRect(x: cropX * sc, y: cropY * sc,
                            width: cropW * sc, height: cropH * sc)
        let limites = CGRect(x: 0, y: 0, width: fW * sc, height: fH * sc)
        let recorte = cropPx.intersection(limites)

        guard !recorte.isNull,
              let cg = img.cgImage?.cropping(to: recorte) else { return img }
        return UIImage(cgImage: cg, scale: sc, orientation: .up)
    }

    private func normalizar(_ img: UIImage) -> UIImage {
        guard img.imageOrientation != .up else { return img }
        return UIGraphicsImageRenderer(size: img.size).image { _ in
            img.draw(in: CGRect(origin: .zero, size: img.size))
        }
    }

    private func redimensionar(_ img: UIImage, maxPx: CGFloat) -> UIImage {
        let maior = max(img.size.width, img.size.height)
        guard maior > maxPx else { return img }
        let escala = maxPx / maior
        let novo = CGSize(width: img.size.width * escala, height: img.size.height * escala)
        return UIGraphicsImageRenderer(size: novo).image { _ in
            img.draw(in: CGRect(origin: .zero, size: novo))
        }
    }
}

#Preview("Câmera ajustável") {
    CapaCameraView { _ in }
}
