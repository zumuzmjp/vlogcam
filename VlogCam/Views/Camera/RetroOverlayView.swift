import SwiftUI

struct RetroOverlayView: View {
    let isRecording: Bool

    @State private var recPulse = false

    var body: some View {
        ZStack {
            // Vignette
            RadialGradient(
                colors: [.clear, .black.opacity(0.35)],
                center: .center,
                startRadius: 150,
                endRadius: 450
            )

            // Recording red border
            if isRecording {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red, lineWidth: 4)
                    .opacity(recPulse ? 1.0 : 0.4)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: recPulse)
                    .padding(2)
            }

            // Corner marks (viewfinder style)
            GeometryReader { geo in
                let inset: CGFloat = 20
                let markLen: CGFloat = 30
                let lineW: CGFloat = 2
                let color = isRecording ? Color.red.opacity(0.8) : RetroTheme.cream.opacity(0.5)

                // Top-left
                Path { p in
                    p.move(to: CGPoint(x: inset, y: inset + markLen))
                    p.addLine(to: CGPoint(x: inset, y: inset))
                    p.addLine(to: CGPoint(x: inset + markLen, y: inset))
                }.stroke(color, lineWidth: lineW)

                // Top-right
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width - inset - markLen, y: inset))
                    p.addLine(to: CGPoint(x: geo.size.width - inset, y: inset))
                    p.addLine(to: CGPoint(x: geo.size.width - inset, y: inset + markLen))
                }.stroke(color, lineWidth: lineW)

                // Bottom-left
                Path { p in
                    p.move(to: CGPoint(x: inset, y: geo.size.height - inset - markLen))
                    p.addLine(to: CGPoint(x: inset, y: geo.size.height - inset))
                    p.addLine(to: CGPoint(x: inset + markLen, y: geo.size.height - inset))
                }.stroke(color, lineWidth: lineW)

                // Bottom-right
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width - inset - markLen, y: geo.size.height - inset))
                    p.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset))
                    p.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset - markLen))
                }.stroke(color, lineWidth: lineW)
            }

        }
        .allowsHitTesting(false)
        .onChange(of: isRecording) { _, recording in
            recPulse = recording
        }
    }
}
