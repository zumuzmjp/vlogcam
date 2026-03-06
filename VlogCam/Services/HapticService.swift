import UIKit
import AudioToolbox

enum HapticService {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Low-level haptic via AudioToolbox — works during AVCaptureSession
    /// 1519 = strong (peek), 1520 = weak (pop), 1521 = medium
    static func peek() {
        AudioServicesPlaySystemSound(1519)
    }

    static func pop() {
        AudioServicesPlaySystemSound(1520)
    }

    static func tick() {
        AudioServicesPlaySystemSound(1521)
    }
}
