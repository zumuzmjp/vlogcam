import SwiftUI

struct StitchProgressView: View {
    let progress: Float

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(RetroTheme.surfaceBackground, lineWidth: 8)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(RetroTheme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(VintageFont.title(20))
                    .foregroundStyle(RetroTheme.textPrimary)
            }
            Text("Stitching clips...")
                .font(VintageFont.body(14))
                .foregroundStyle(RetroTheme.textSecondary)
        }
    }
}
