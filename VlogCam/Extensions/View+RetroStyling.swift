import SwiftUI

extension View {
    func retroCard() -> some View {
        self
            .background(RetroTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: RetroTheme.cornerRadius))
            .shadow(color: RetroTheme.cardShadow, radius: 6, y: 4)
    }

    func retroOverlay() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: RetroTheme.cornerRadius)
                .stroke(RetroTheme.warmBrown.opacity(0.3), lineWidth: 1)
        )
    }

    func vintageVignette() -> some View {
        self.overlay(
            RadialGradient(
                colors: [.clear, .black.opacity(0.4)],
                center: .center,
                startRadius: 200,
                endRadius: 500
            )
            .allowsHitTesting(false)
        )
    }
}
