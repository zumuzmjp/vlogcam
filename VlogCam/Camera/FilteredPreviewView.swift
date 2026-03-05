import UIKit
import MetalKit
import CoreImage
import AVFoundation

final class FilteredPreviewView: MTKView, MTKViewDelegate {
    private let ciContext: CIContext
    private let commandQueue: MTLCommandQueue

    var filterEnabled: Bool = false
    var filterProcessor: FilmFilterProcessor?
    var filterType: FilmFilterType = .none
    var filterParams: FilmFilterParams = .defaultLight

    // Store latest image atomically — capture and render are decoupled
    private var currentCIImage: CIImage?
    private let imageLock = NSLock()

    override init(frame: CGRect, device: MTLDevice?) {
        let metalDevice = device ?? MTLCreateSystemDefaultDevice()!
        let queue = metalDevice.makeCommandQueue()!
        self.commandQueue = queue
        self.ciContext = CIContext(mtlDevice: metalDevice, options: [
            .cacheIntermediates: false
        ])
        super.init(frame: frame, device: metalDevice)
        self.delegate = self
        self.framebufferOnly = false
        self.isPaused = true                   // We drive draws manually
        self.enableSetNeedsDisplay = false
        self.contentScaleFactor = UIScreen.main.scale
        self.autoResizeDrawable = true
        self.contentMode = .scaleAspectFill
        self.clipsToBounds = true
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func render(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply filter
        if filterEnabled, filterType != .none, let processor = filterProcessor {
            ciImage = processor.apply(filter: filterType, params: filterParams, to: ciImage)
        }

        imageLock.lock()
        currentCIImage = ciImage
        imageLock.unlock()

        // Trigger draw on next display refresh
        draw()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        imageLock.lock()
        guard let ciImage = currentCIImage else {
            imageLock.unlock()
            return
        }
        imageLock.unlock()

        guard let drawable = currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let drawableSize = view.drawableSize
        let imageExtent = ciImage.extent

        // Aspect-fill: scale so image covers entire drawable
        let scaleX = drawableSize.width / imageExtent.width
        let scaleY = drawableSize.height / imageExtent.height
        let scale = max(scaleX, scaleY)
        let scaledWidth = imageExtent.width * scale
        let scaledHeight = imageExtent.height * scale
        let offsetX = (drawableSize.width - scaledWidth) / 2
        let offsetY = (drawableSize.height - scaledHeight) / 2

        let scaledImage = ciImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))

        let destination = CIRenderDestination(
            width: Int(drawableSize.width),
            height: Int(drawableSize.height),
            pixelFormat: view.colorPixelFormat,
            commandBuffer: commandBuffer
        ) {
            return drawable.texture
        }

        do {
            try ciContext.startTask(toRender: scaledImage, to: destination)
        } catch {
            return
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
