import AVFoundation
import UIKit

final class CameraService: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var currentDevice: AVCaptureDevice?

    @Published var isSessionRunning = false
    @Published var permissionGranted = false
    @Published var setupError: String?

    var movieFileOutput: AVCaptureMovieFileOutput { movieOutput }

    func checkPermissions() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await MainActor.run { permissionGranted = true }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
            await MainActor.run { permissionGranted = granted }
        default:
            await MainActor.run { permissionGranted = false }
        }
    }

    func setupSession() {
        guard permissionGranted else { return }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080

        // Video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            setupError = "No camera available"
            captureSession.commitConfiguration()
            return
        }
        currentDevice = videoDevice

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            setupError = "Camera input error: \(error.localizedDescription)"
            captureSession.commitConfiguration()
            return
        }

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
            } catch {
                // Audio optional — continue without
            }
        }

        // Movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            if let connection = movieOutput.connection(with: .video) {
                connection.preferredVideoStabilizationMode = .auto
            }
        }

        captureSession.commitConfiguration()
    }

    func startSession() {
        guard !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.captureSession.isRunning ?? false
            }
        }
    }

    func stopSession() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }

    func switchCamera() {
        captureSession.beginConfiguration()
        guard let currentInput = captureSession.inputs.first(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true }) as? AVCaptureDeviceInput else {
            captureSession.commitConfiguration()
            return
        }

        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            captureSession.commitConfiguration()
            return
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            captureSession.removeInput(currentInput)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                currentDevice = newDevice
            }
        } catch {
            // Revert
            if captureSession.canAddInput(currentInput) {
                captureSession.addInput(currentInput)
            }
        }
        captureSession.commitConfiguration()
    }
}
