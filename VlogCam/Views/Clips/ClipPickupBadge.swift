import SwiftUI

struct ClipPickupBadge: View {
    let pickupState: ClipPickupState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "film.stack")
                .font(.system(size: 14, weight: .semibold))
            Text("\(pickupState.pickedClips.count) clips picked up")
                .font(VintageFont.label(13))
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    pickupState.cancel()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RetroTheme.accent.opacity(0.9))
        .clipShape(Capsule())
        .shadow(radius: 4)
    }
}
