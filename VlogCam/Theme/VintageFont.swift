import SwiftUI

enum VintageFont {
    static func title(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func label(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}
