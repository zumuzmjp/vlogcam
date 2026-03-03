import SwiftUI

struct ClipCounterView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "film.stack")
                .font(.system(size: 12))
            Text("\(count)")
                .font(VintageFont.caption())
        }
        .foregroundStyle(RetroTheme.cream)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RetroTheme.darkBrown.opacity(0.8))
        .clipShape(Capsule())
    }
}
