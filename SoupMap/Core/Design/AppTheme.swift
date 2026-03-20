import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.094)
    static let backgroundSecondary = Color(red: 0.094, green: 0.106, blue: 0.149)
    static let panel = Color.white.opacity(0.08)
    static let panelStrong = Color.white.opacity(0.12)
    static let hairline = Color.white.opacity(0.09)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.52)
    static let success = Color(red: 0.45, green: 0.87, blue: 0.54)
    static let warning = Color(red: 0.96, green: 0.73, blue: 0.33)
    static let danger = Color(red: 0.95, green: 0.39, blue: 0.39)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.032, green: 0.039, blue: 0.063),
            Color(red: 0.086, green: 0.118, blue: 0.188),
            Color(red: 0.055, green: 0.063, blue: 0.094)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct BubblePalette {
    let fill: Color
    let halo: Color
    let text: Color
}

extension View {
    func soupGlass(cornerRadius: CGFloat = 24, strokeOpacity: CGFloat = 0.12) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}
