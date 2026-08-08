import SwiftUI

/// Paleta de cores espelhada do app Biblioteca (Mac / biblioteca.html)
extension Color {
    static let bibPrimary = Color(red: 0x2b/255, green: 0x5f/255, blue: 0xb3/255) // #2b5fb3
    static let bibAccent  = Color(red: 0x1e/255, green: 0x8a/255, blue: 0x5f/255) // #1e8a5f
    static let bibDanger  = Color(red: 0xc0/255, green: 0x39/255, blue: 0x2b/255) // #c0392b
    static let bibMuted   = Color(red: 0x6b/255, green: 0x72/255, blue: 0x80/255) // #6b7280
    static let bibBorder  = Color(red: 0xe2/255, green: 0xe6/255, blue: 0xee/255) // #e2e6ee
    static let bibText    = Color(red: 0x1f/255, green: 0x29/255, blue: 0x37/255) // #1f2937
}

/// Gradiente do cabeçalho (135°, azul → verde) — igual ao topo do app do Mac
let bibHeaderGradient = LinearGradient(
    colors: [.bibPrimary, .bibAccent],
    startPoint: .topLeading, endPoint: .bottomTrailing
)
