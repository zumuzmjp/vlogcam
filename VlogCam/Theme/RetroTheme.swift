import SwiftUI

enum RetroTheme {
    // Primary palette
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.87)
    static let warmBrown = Color(red: 0.55, green: 0.35, blue: 0.22)
    static let darkBrown = Color(red: 0.30, green: 0.18, blue: 0.10)
    static let accent = Color(red: 0.85, green: 0.45, blue: 0.25)
    static let leather = Color(red: 0.65, green: 0.42, blue: 0.28)
    static let olive = Color(red: 0.45, green: 0.50, blue: 0.30)
    static let faded = Color(red: 0.78, green: 0.73, blue: 0.65)

    // Backgrounds
    static let background = Color(red: 0.18, green: 0.15, blue: 0.12)
    static let cardBackground = Color(red: 0.25, green: 0.20, blue: 0.16)
    static let surfaceBackground = Color(red: 0.22, green: 0.18, blue: 0.14)

    // Text
    static let textPrimary = cream
    static let textSecondary = faded
    static let textAccent = accent

    // Gradients
    static let leatherGradient = LinearGradient(
        colors: [leather, warmBrown],
        startPoint: .top,
        endPoint: .bottom
    )

    static let darkGradient = LinearGradient(
        colors: [surfaceBackground, background],
        startPoint: .top,
        endPoint: .bottom
    )

    // Camera body
    static let cameraBody = Color(red: 0.12, green: 0.11, blue: 0.10)
    static let cameraBodyLight = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let metalDark = Color(red: 0.25, green: 0.24, blue: 0.22)
    static let metalLight = Color(red: 0.55, green: 0.53, blue: 0.50)
    static let metalHighlight = Color(red: 0.75, green: 0.73, blue: 0.70)

    // Shadows
    static let cardShadow: Color = .black.opacity(0.4)
    static let embossShadow: Color = .white.opacity(0.15)

    // Corner radius
    static let cornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8
}
