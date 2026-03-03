import SwiftUI
import CoreMotion
import AVFoundation
import Combine

@MainActor
final class DeviceOrientationManager: ObservableObject {
    @Published var deviceOrientation: AVCaptureVideoOrientation = .portrait
    @Published var isLandscape: Bool = false
    @Published var iconRotationAngle: Double = 0

    private let motionManager = CMMotionManager()
    private let threshold: Double = 0.55

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 5.0 // 5Hz

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            Task { @MainActor in
                self.processAccelerometer(x: data.acceleration.x, y: data.acceleration.y)
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }

    private func processAccelerometer(x: Double, y: Double) {
        let newOrientation: AVCaptureVideoOrientation
        let newAngle: Double

        if abs(x) > abs(y) {
            // Landscape dominant
            guard abs(x) > threshold else { return }
            if x > 0 {
                // Right edge down (rotated CW)
                newOrientation = .landscapeLeft
                newAngle = -90
            } else {
                // Left edge down (rotated CCW)
                newOrientation = .landscapeRight
                newAngle = 90
            }
        } else {
            // Portrait dominant
            guard abs(y) > threshold else { return }
            if y < 0 {
                newOrientation = .portrait
                newAngle = 0
            } else {
                // Upside down – treat as portrait (most apps ignore upside down)
                return
            }
        }

        guard newOrientation != deviceOrientation else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            deviceOrientation = newOrientation
            isLandscape = (newOrientation == .landscapeLeft || newOrientation == .landscapeRight)
            iconRotationAngle = newAngle
        }
    }
}
