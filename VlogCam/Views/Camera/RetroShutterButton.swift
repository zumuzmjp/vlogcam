import SwiftUI

struct RetroShutterButton: View {
    let isRecording: Bool
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer metallic ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [RetroTheme.metalLight, RetroTheme.metalDark, .black],
                            center: .center,
                            startRadius: 20,
                            endRadius: 44
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(RetroTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: progress)

                // Middle ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [RetroTheme.metalHighlight, RetroTheme.metalLight, RetroTheme.metalDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                // Inner lens / button
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                isRecording ? Color.red : RetroTheme.metalDark,
                                isRecording ? Color.red.opacity(0.7) : .black
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: 36, height: 36)

                // Highlight dot
                Circle()
                    .fill(.white.opacity(0.4))
                    .frame(width: 6, height: 6)
                    .offset(x: -6, y: -6)
            }
        }
        .buttonStyle(.plain)
    }
}
