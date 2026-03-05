import SwiftUI

struct ZoomDialView: View {
    @Binding var displayZoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onZoomChanged: (CGFloat) -> Void

    private let trackHeight: CGFloat = 130
    private let knobSize: CGFloat = 24

    // Logarithmic scale: 0.5→5.0 mapped to 0→1
    private var normalizedValue: CGFloat {
        guard maxDialZoom > minDialZoom else { return 0.5 }
        return log(displayZoom / minDialZoom) / log(maxDialZoom / minDialZoom)
    }

    private func zoomForNormalized(_ n: CGFloat) -> CGFloat {
        minDialZoom * pow(maxDialZoom / minDialZoom, n)
    }

    private func normalizedForZoom(_ z: CGFloat) -> CGFloat {
        log(z / minDialZoom) / log(maxDialZoom / minDialZoom)
    }

    private var minDialZoom: CGFloat { max(minZoom, 0.5) }
    private var maxDialZoom: CGFloat { min(maxZoom, 5.0) }

    var body: some View {
        VStack(spacing: 4) {
            Text(zoomLabel)
                .font(VintageFont.lcd(10))
                .foregroundStyle(RetroTheme.cream.opacity(0.7))

            GeometryReader { geo in
                let available = geo.size.height - knobSize
                let knobY = available * (1 - normalizedValue)

                ZStack(alignment: .top) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.black, RetroTheme.cameraBodyLight, .black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 14)
                        .frame(maxHeight: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(RetroTheme.metalDark.opacity(0.5), lineWidth: 1)
                        )

                    // Tick marks at logarithmic positions
                    ForEach([(5.0, "5x"), (2.0, "2x"), (1.0, "1x"), (0.5, ".5")], id: \.0) { zoom, label in
                        let n = normalizedForZoom(zoom)
                        let yPos = available * (1 - n) + knobSize / 2
                        Text(label)
                            .font(VintageFont.lcd(7))
                            .foregroundStyle(RetroTheme.faded.opacity(0.4))
                            .position(x: geo.size.width / 2 + 18, y: yPos)
                    }
                    .allowsHitTesting(false)

                    // Knob
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [RetroTheme.metalHighlight, RetroTheme.metalLight, RetroTheme.metalDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 22, height: knobSize)
                        .overlay(
                            VStack(spacing: 2) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Rectangle()
                                        .fill(.black.opacity(0.3))
                                        .frame(width: 12, height: 1)
                                }
                            }
                        )
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .offset(y: knobY)
                }
                .frame(maxWidth: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = 1 - ((value.location.y - knobSize / 2) / available)
                            let clamped = max(0, min(1, ratio))
                            let newZoom = zoomForNormalized(clamped)
                            onZoomChanged(newZoom)
                        }
                )
            }
            .frame(height: trackHeight)
        }
        .frame(width: 44)
    }

    private var zoomLabel: String {
        if displayZoom < 1.0 {
            return String(format: "%.1fx", displayZoom)
        } else {
            return String(format: "%.1fx", displayZoom)
        }
    }
}
