import SwiftUI

struct DurationLeverView: View {
    @Binding var duration: Double
    private let options: [Double] = [1, 2, 3]

    // Lever angle range: -45° (1s) to +45° (3s), center = 2s
    private let minAngle: Double = -45
    private let maxAngle: Double = 45
    private let baseRadius: CGFloat = 28

    @State private var lastSnappedIndex: Int? = nil

    private var currentIndex: Int {
        options.firstIndex(of: duration) ?? 2
    }

    private func angle(for index: Int) -> Double {
        let count = Double(options.count - 1)
        guard count > 0 else { return 0 }
        return minAngle + (maxAngle - minAngle) * Double(index) / count
    }

    private func indexForAngle(_ angle: Double) -> Int {
        let count = Double(options.count - 1)
        let ratio = (angle - minAngle) / (maxAngle - minAngle)
        let clamped = max(0, min(1, ratio))
        return Int(round(clamped * count))
    }

    private var displayAngle: Double {
        angle(for: currentIndex)
    }

    var body: some View {
        leverContent
            .rotationEffect(.degrees(90))
            .frame(width: 90, height: 100)
            .contentShape(Rectangle())
            .gesture(leverDragGesture)
    }

    private var leverContent: some View {
        ZStack {
            // Notch marks at each position
            ForEach(Array(options.enumerated()), id: \.offset) { i, value in
                let a = angle(for: i)
                let isSelected = currentIndex == i

                // Tick line
                Rectangle()
                    .fill(isSelected ? RetroTheme.cream : RetroTheme.faded.opacity(0.3))
                    .frame(width: isSelected ? 2 : 1.5, height: isSelected ? 10 : 7)
                    .offset(y: -(baseRadius + 10))
                    .rotationEffect(.degrees(a))

                // Label — counter-rotate so text stays upright
                Text("\(Int(value))s")
                    .font(VintageFont.lcd(isSelected ? 11 : 9))
                    .foregroundStyle(isSelected ? RetroTheme.cream : RetroTheme.faded.opacity(0.4))
                    .rotationEffect(.degrees(-90))
                    .offset(
                        x: sin(a * .pi / 180) * (baseRadius + 24),
                        y: -(cos(a * .pi / 180) * (baseRadius + 24))
                    )
            }

            // Base plate
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            RetroTheme.cameraBodyLight,
                            RetroTheme.cameraBody,
                            .black.opacity(0.8)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: baseRadius
                    )
                )
                .frame(width: baseRadius * 2, height: baseRadius * 2)
                .overlay(
                    Circle()
                        .stroke(RetroTheme.metalDark.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 3, y: 2)

            // Center rivet
            Circle()
                .fill(
                    LinearGradient(
                        colors: [RetroTheme.metalHighlight, RetroTheme.metalLight, RetroTheme.metalDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 12, height: 12)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)

            // Lever arm (points upward in original, rightward after 90° rotation)
            VStack(spacing: 0) {
                // Knob at tip
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [RetroTheme.metalHighlight, RetroTheme.metalLight, RetroTheme.metalDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 12, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(.black.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)

                // Arm shaft
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [RetroTheme.metalLight, RetroTheme.metalDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 5, height: baseRadius - 8)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 1)
            }
            .offset(y: -(baseRadius / 2 + 2))
            .rotationEffect(.degrees(displayAngle))
            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: displayAngle)
        }
        .frame(width: 100, height: 90)
    }

    private var leverDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Rotated 90° CW: screen coords → original coords
                // original_dx = screen_dy, original_dy = -screen_dx
                let screenCenter = CGPoint(x: 45, y: 50)
                let screenDx = value.location.x - screenCenter.x
                let screenDy = value.location.y - screenCenter.y
                let dx = screenDy
                let dy = -screenDx
                let rawAngle = atan2(dx, -dy) * 180 / .pi
                let clamped = max(minAngle, min(maxAngle, rawAngle))

                let snapIndex = indexForAngle(clamped)
                if snapIndex != lastSnappedIndex {
                    lastSnappedIndex = snapIndex
                    duration = options[snapIndex]
                    HapticService.peek()
                }
            }
            .onEnded { _ in
                lastSnappedIndex = nil
            }
    }
}
