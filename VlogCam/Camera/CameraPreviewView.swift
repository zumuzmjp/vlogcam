import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapToFocus: ((_ devicePoint: CGPoint, _ viewLocation: CGPoint) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapToFocus: onTapToFocus)
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.previewLayer = view.previewLayer

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        context.coordinator.onTapToFocus = onTapToFocus
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

class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
