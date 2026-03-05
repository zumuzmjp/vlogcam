import CoreImage

enum FilmFilterType: String, CaseIterable, Identifiable {
    case none
    case glow
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "OFF"
        case .glow: return "GLOW"
        case .light: return "LIGHT"
        }
    }
}

struct FilmFilterParams {
    var blur: Float = 50       // 0-100
    var opacity: Float = 60    // 0-100
    var range: Float = 40      // 0-100

    static let defaultGlow = FilmFilterParams(blur: 40, opacity: 50, range: 50)
    static let defaultLight = FilmFilterParams(blur: 53, opacity: 64, range: 43)
}

final class FilmFilterProcessor {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func apply(filter: FilmFilterType, params: FilmFilterParams, to image: CIImage) -> CIImage {
        switch filter {
        case .none:
            return image
        case .glow:
            return applyGlow(to: image, params: params)
        case .light:
            return applyLight(to: image, params: params)
        }
    }

    // MARK: - Glow (Bloom)

    private func applyGlow(to image: CIImage, params: FilmFilterParams) -> CIImage {
        let clamped = image.clampedToExtent()
        let radius = Double(params.blur) * 0.5
        let intensity = Double(params.opacity) / 100.0

        guard let bloom = CIFilter(name: "CIBloom") else { return image }
        bloom.setValue(clamped, forKey: kCIInputImageKey)
        bloom.setValue(radius, forKey: kCIInputRadiusKey)
        bloom.setValue(intensity, forKey: kCIInputIntensityKey)

        return bloom.outputImage?.cropped(to: image.extent) ?? image
    }

    // MARK: - Light (Pro-Mist Diffusion)
    // Extract highlights above threshold, blur them, screen-blend back

    private func applyLight(to image: CIImage, params: FilmFilterParams) -> CIImage {
        let extent = image.extent

        // 1. Extract highlights: raise brightness to isolate bright areas
        let threshold = 1.0 - Double(params.range) / 100.0 // higher range = lower threshold = more glow
        guard let brightnessClamp = CIFilter(name: "CIColorMatrix") else { return image }
        // Shift colors so only bright areas remain
        let bias = CIVector(x: -threshold, y: -threshold, z: -threshold, w: 0)
        let scale = 1.0 / (1.0 - threshold)
        brightnessClamp.setValue(image, forKey: kCIInputImageKey)
        brightnessClamp.setValue(CIVector(x: scale, y: 0, z: 0, w: 0), forKey: "inputRVector")
        brightnessClamp.setValue(CIVector(x: 0, y: scale, z: 0, w: 0), forKey: "inputGVector")
        brightnessClamp.setValue(CIVector(x: 0, y: 0, z: scale, w: 0), forKey: "inputBVector")
        brightnessClamp.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        brightnessClamp.setValue(bias, forKey: "inputBiasVector")

        guard let highlights = brightnessClamp.outputImage else { return image }

        // 2. Blur the highlights
        let blurRadius = Double(params.blur) * 0.6
        let clamped = highlights.clampedToExtent()
        guard let blurred = CIFilter(name: "CIGaussianBlur") else { return image }
        blurred.setValue(clamped, forKey: kCIInputImageKey)
        blurred.setValue(blurRadius, forKey: kCIInputRadiusKey)

        guard let blurredImage = blurred.outputImage?.cropped(to: extent) else { return image }

        // 3. Screen blend the blurred highlights back onto original
        let opacity = Double(params.opacity) / 100.0
        guard let opacityFilter = CIFilter(name: "CIColorMatrix") else { return image }
        opacityFilter.setValue(blurredImage, forKey: kCIInputImageKey)
        opacityFilter.setValue(CIVector(x: opacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
        opacityFilter.setValue(CIVector(x: 0, y: opacity, z: 0, w: 0), forKey: "inputGVector")
        opacityFilter.setValue(CIVector(x: 0, y: 0, z: opacity, w: 0), forKey: "inputBVector")
        opacityFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: opacity), forKey: "inputAVector")
        opacityFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")

        guard let adjustedHighlights = opacityFilter.outputImage else { return image }

        // Screen blend: result = 1 - (1 - base) * (1 - blend)
        guard let screenBlend = CIFilter(name: "CIScreenBlendMode") else { return image }
        screenBlend.setValue(image, forKey: kCIInputBackgroundImageKey)
        screenBlend.setValue(adjustedHighlights, forKey: kCIInputImageKey)

        return screenBlend.outputImage?.cropped(to: extent) ?? image
    }
}
