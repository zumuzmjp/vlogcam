import AVFoundation
import Combine

protocol ClipRecordingDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidFinish(outputURL: URL, duration: Double)
    func recordingDidFail(error: Error)
}

final class ClipRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingProgress: Double = 0
    @Published var maxDuration: Double = 3.0

    weak var delegate: ClipRecordingDelegate?
    private weak var movieOutput: AVCaptureMovieFileOutput?
    private var timer: Timer?
    private var startTime: Date?
    private let clipStorage = ClipStorageService.shared

    func configure(movieOutput: AVCaptureMovieFileOutput) {
        self.movieOutput = movieOutput
    }

    func startRecording() {
        guard let movieOutput, !movieOutput.isRecording else { return }

        do {
            try clipStorage.ensureDirectories()
        } catch {
            delegate?.recordingDidFail(error: error)
            return
        }

        let fileName = clipStorage.generateClipFileName()
        let outputURL = clipStorage.clipURL(for: fileName)

        movieOutput.maxRecordedDuration = CMTime(seconds: maxDuration, preferredTimescale: 600)
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
    }

    func stopRecording() {
        guard let movieOutput, movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    private func startTimer() {
        startTime = Date()
        recordingProgress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.startTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                self.recordingProgress = min(elapsed / self.maxDuration, 1.0)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        DispatchQueue.main.async {
            self.recordingProgress = 0
        }
    }
}

extension ClipRecordingManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        Task { @MainActor in
            self.isRecording = true
            self.startTimer()
            self.delegate?.recordingDidStart()
        }
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            self.stopTimer()

            if let error {
                // Check if recording reached max duration (not an error)
                let nsError = error as NSError
                if nsError.domain == AVFoundationErrorDomain &&
                   nsError.code == AVError.maximumDurationReached.rawValue {
                    let asset = AVURLAsset(url: outputFileURL)
                    let duration = CMTimeGetSeconds(asset.duration)
                    if duration >= 0.5 {
                        self.delegate?.recordingDidFinish(outputURL: outputFileURL, duration: duration)
                    }
                } else {
                    self.delegate?.recordingDidFail(error: error)
                }
                return
            }

            let asset = AVURLAsset(url: outputFileURL)
            let duration = CMTimeGetSeconds(asset.duration)

            if duration < 0.5 {
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }

            self.delegate?.recordingDidFinish(outputURL: outputFileURL, duration: duration)
        }
    }
}
