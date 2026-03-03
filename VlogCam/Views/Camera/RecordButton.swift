import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(RetroTheme.cream.opacity(0.6), lineWidth: 4)
                    .frame(width: 76, height: 76)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(RetroTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: progress)

                // Inner circle
                Circle()
                    .fill(isRecording ? RetroTheme.accent : RetroTheme.accent.opacity(0.9))
                    .frame(width: isRecording ? 32 : 60, height: isRecording ? 32 : 60)
                    .clipShape(isRecording ? AnyShape(RoundedRectangle(cornerRadius: 8)) : AnyShape(Circle()))
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
        .buttonStyle(.plain)
    }
}
