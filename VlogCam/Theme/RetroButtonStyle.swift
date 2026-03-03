import SwiftUI

struct RetroButtonStyle: ButtonStyle {
    var color: Color = RetroTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(RetroTheme.cream)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: RetroTheme.smallCornerRadius)
                        .fill(color)
                    RoundedRectangle(cornerRadius: RetroTheme.smallCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .shadow(color: RetroTheme.cardShadow, radius: configuration.isPressed ? 2 : 4, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
