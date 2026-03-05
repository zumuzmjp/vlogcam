import SwiftUI

struct DurationLeverView: View {
    @Binding var duration: Double
    private let options: [Double] = [1, 2, 3]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { value in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        duration = value
                    }
                    HapticService.impact(.light)
                } label: {
                    Text("\(Int(value))s")
                        .font(VintageFont.caption(11))
                        .foregroundStyle(duration == value ? RetroTheme.cameraBody : RetroTheme.cream.opacity(0.6))
                        .frame(width: 36, height: 26)
                        .background(
                            duration == value
                                ? RetroTheme.metalHighlight
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(RetroTheme.cameraBody)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(RetroTheme.metalDark.opacity(0.6), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
