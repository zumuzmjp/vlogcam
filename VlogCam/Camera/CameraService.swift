import AVFoundation
import UIKit

final class CameraService: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataQueue = DispatchQueue(label: "com.vlogcam.videodata", qos: .userInteractive)
    private var currentDevice: AVCaptureDevice?
    private var wideBaseFactor: CGFloat = 1.0

    var onVideoFrame: ((CMSampleBuffer) -> Void)?

    @Published var isSessionRunning = false
    @Published var permissionGranted = false
    @Published var setupError: String?
    @Published var displayZoomFactor: CGFloat = 1.0

    var minDisplayZoom: CGFloat {
        let deviceMin = currentDevice?.minAvailableVideoZoomFactor ?? 1.0
        return deviceMin / wideBaseFactor
    }

    var maxDisplayZoom: CGFloat {
        let deviceMax = min(currentDevice?.activeFormat.videoMaxZoomFactor ?? 5.0, 20.0)
        return deviceMax / wideBaseFactor
    }

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
        captureSession.sessionPreset = .inputPriority

        guard let videoDevice = resolveBackCamera() else {
            setupError = "No camera available"
            captureSession.commitConfiguration()
            return
        }
        currentDevice = videoDevice
        configureWideBaseFactor(for: videoDevice)

        // Select best 1080p format with highest zoom range
        selectBestFormat(for: videoDevice)

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
            } catch {}
        }

        // Movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            if let connection = movieOutput.connection(with: .video) {
                connection.preferredVideoStabilizationMode = .off
            }
        }

        // Video data output for filtered preview
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
            }
        }

        captureSession.commitConfiguration()

        // Set initial zoom to 1.0x (wide lens)
        setZoom(display: 1.0)
    }

    private func selectBestFormat(for device: AVCaptureDevice) {
        // Find 1080p 30fps format with max zoom support
        let targetWidth: Int32 = 1920
        let targetHeight: Int32 = 1080
        var bestFormat: AVCaptureDevice.Format?
        var bestZoom: CGFloat = 0

        for format in device.formats {
            let desc = format.formatDescription
            let dims = CMVideoFormatDescriptionGetDimensions(desc)
            guard dims.width >= targetWidth, dims.height >= targetHeight else { continue }

            let ranges = format.videoSupportedFrameRateRanges
            let supports30fps = ranges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
            guard supports30fps else { continue }

            if format.videoMaxZoomFactor > bestZoom {
                bestZoom = format.videoMaxZoomFactor
                bestFormat = format
            }
        }

        if let best = bestFormat {
            do {
                try device.lockForConfiguration()
                device.activeFormat = best
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    private func resolveBackCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInWideAngleCamera
        ]
        for type in types {
            if let device = AVCaptureDevice.default(type, for: .video, position: .back) {
                return device
            }
        }
        return nil
    }

    private func configureWideBaseFactor(for device: AVCaptureDevice) {
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors
        if let first = switchOvers.first {
            wideBaseFactor = CGFloat(truncating: first)
        } else {
            wideBaseFactor = 1.0
        }
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

    func setZoom(display: CGFloat) {
        guard let device = currentDevice else { return }
        let deviceFactor = display * wideBaseFactor
        let clamped = max(device.minAvailableVideoZoomFactor,
                          min(deviceFactor, device.activeFormat.videoMaxZoomFactor))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.displayZoomFactor = clamped / self.wideBaseFactor }
        } catch {}
    }

    func focus(at point: CGPoint) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {}
    }

    func switchCamera() {
        captureSession.beginConfiguration()
        guard let currentInput = captureSession.inputs.first(where: {
            ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true
        }) as? AVCaptureDeviceInput else {
            captureSession.commitConfiguration()
            return
        }

        let newDevice: AVCaptureDevice?
        if currentInput.device.position == .back {
            newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        } else {
            newDevice = resolveBackCamera()
        }

        guard let device = newDevice else {
            captureSession.commitConfiguration()
            return
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            captureSession.removeInput(currentInput)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                currentDevice = device
                configureWideBaseFactor(for: device)
                DispatchQueue.main.async { self.displayZoomFactor = 1.0 }
            }
        } catch {
            if captureSession.canAddInput(currentInput) {
                captureSession.addInput(currentInput)
            }
        }
        captureSession.commitConfiguration()

        // Reset to 1.0x on new camera
        setZoom(display: 1.0)
    }
}

// MARK: - Video Data Output Delegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onVideoFrame?(sampleBuffer)
    }
}
