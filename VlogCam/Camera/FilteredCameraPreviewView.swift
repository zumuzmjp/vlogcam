import SwiftUI
import AVFoundation

struct FilteredCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let cameraService: CameraService
    let filterProcessor: FilmFilterProcessor
    let filterType: FilmFilterType
    let filterParams: FilmFilterParams
    var onTapToFocus: ((_ devicePoint: CGPoint, _ viewLocation: CGPoint) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapToFocus: onTapToFocus)
    }

    func makeUIView(context: Context) -> FilteredPreviewContainerView {
        let view = FilteredPreviewContainerView()
        view.setupPreview(session: session)
        view.filteredView.filterProcessor = filterProcessor

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.previewLayer = view.previewLayer

        // Connect video frame callback
        cameraService.onVideoFrame = { [weak view] sampleBuffer in
            view?.filteredView.render(sampleBuffer: sampleBuffer)
        }

        return view
    }

    func updateUIView(_ uiView: FilteredPreviewContainerView, context: Context) {
        context.coordinator.onTapToFocus = onTapToFocus
        let isFiltered = filterType != .none
        uiView.setFilterEnabled(isFiltered)
        uiView.filteredView.filterType = filterType
        uiView.filteredView.filterParams = filterParams
        uiView.filteredView.filterEnabled = isFiltered
    }

    class Coordinator {
        var onTapToFocus: ((_ devicePoint: CGPoint, _ viewLocation: CGPoint) -> Void)?
        weak var previewLayer: AVCaptureVideoPreviewLayer?

        init(onTapToFocus: ((_ devicePoint: CGPoint, _ viewLocation: CGPoint) -> Void)?) {
            self.onTapToFocus = onTapToFocus
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let previewLayer, let view = gesture.view else { return }
            let locationInView = gesture.location(in: view)
            let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: locationInView)
            onTapToFocus?(devicePoint, locationInView)
        }
    }
}

// Container that holds both the unfiltered preview layer and the filtered Metal view
class FilteredPreviewContainerView: UIView {
    let filteredView = FilteredPreviewView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    private var previewUIView: PreviewUIView!

    var previewLayer: AVCaptureVideoPreviewLayer? {
        previewUIView?.previewLayer
    }

    func setupPreview(session: AVCaptureSession) {
        // Unfiltered preview (shown when no filter)
        previewUIView = PreviewUIView()
        previewUIView.previewLayer.session = session
        previewUIView.previewLayer.videoGravity = .resizeAspectFill
        addSubview(previewUIView)

        // Filtered Metal view (shown when filter active)
        filteredView.isHidden = true
        addSubview(filteredView)
    }

    func setFilterEnabled(_ enabled: Bool) {
        previewUIView.isHidden = enabled
        filteredView.isHidden = !enabled
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewUIView?.frame = bounds
        filteredView.frame = bounds
    }
}
