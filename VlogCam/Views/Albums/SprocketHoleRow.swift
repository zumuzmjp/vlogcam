import SwiftUI

struct SprocketHoleRow: View {
    var body: some View {
        GeometryReader { geo in
            let holeWidth: CGFloat = 8
            let holeHeight: CGFloat = 5
            let spacing: CGFloat = 16
            let count = max(1, Int(geo.size.width / spacing))

            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { _ in
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.05))
                        .frame(width: holeWidth, height: holeHeight)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: 14)
        .background(Color(white: 0.12))
    }
}
