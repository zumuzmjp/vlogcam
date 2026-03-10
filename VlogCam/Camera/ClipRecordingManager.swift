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
    /// Duration (seconds) to trim from the start of each clip to remove tap sound
    private static let tapTrimDuration: CMTime = CMTime(seconds: 0.25, preferredTimescale: 600)

    func configure(movieOutput: AVCaptureMovieFileOutput) {
        self.movieOutput = movieOutput
    }

    func startRecording(orientation: AVCaptureVideoOrientation = .portrait) {
        guard let movieOutput, !movieOutput.isRecording else { return }

        do {
            try clipStorage.ensureDirectories()
        } catch {
            delegate?.recordingDidFail(error: error)
            return
        }

        if let connection = movieOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
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
                    await self.trimAndDeliver(outputFileURL)
                } else {
                    self.delegate?.recordingDidFail(error: error)
                }
                return
            }

            await self.trimAndDeliver(outputFileURL)
        }
    }

    /// Trim the first 0.25s (tap sound) from the recorded clip, then notify delegate
    private func trimAndDeliver(_ fileURL: URL) async {
        let asset = AVURLAsset(url: fileURL)
        let totalDuration = CMTimeGetSeconds(asset.duration)

        guard totalDuration >= 0.5 else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        let trimStart = Self.tapTrimDuration
        let assetDuration = asset.duration

        // Skip trim if clip is too short to trim meaningfully
        guard CMTimeCompare(assetDuration, trimStart) == 1 else {
            let duration = CMTimeGetSeconds(assetDuration)
            delegate?.recordingDidFinish(outputURL: fileURL, duration: duration)
            return
        }

        let timeRange = CMTimeRange(start: trimStart, end: assetDuration)
        let composition = AVMutableComposition()

        do {
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                try compVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                compVideoTrack?.preferredTransform = videoTrack.preferredTransform
            }
            if let audioTrack = asset.tracks(withMediaType: .audio).first {
                let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try compAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }
        } catch {
            // Trim failed — deliver original file
            delegate?.recordingDidFinish(outputURL: fileURL, duration: totalDuration)
            return
        }

        // Export trimmed clip to a temp file, then replace the original
        let trimmedURL = fileURL.deletingLastPathComponent()
            .appending(component: "trim_\(fileURL.lastPathComponent)")

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            delegate?.recordingDidFinish(outputURL: fileURL, duration: totalDuration)
            return
        }
        exporter.outputURL = trimmedURL
        exporter.outputFileType = .mov

        await exporter.export()

        if exporter.status == .completed {
            // Replace original with trimmed version
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.moveItem(at: trimmedURL, to: fileURL)
            let trimmedDuration = totalDuration - CMTimeGetSeconds(trimStart)
            delegate?.recordingDidFinish(outputURL: fileURL, duration: trimmedDuration)
        } else {
            // Export failed — deliver original
            try? FileManager.default.removeItem(at: trimmedURL)
            delegate?.recordingDidFinish(outputURL: fileURL, duration: totalDuration)
        }
    }
}
