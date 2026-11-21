import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Vision

enum IconProcessingError: LocalizedError {
    case unreadableImage
    case foregroundNotFound
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "The selected file is not a readable image."
        case .foregroundNotFound: return "No foreground subject could be detected in this image."
        case .exportFailed: return "The transparent icon could not be created."
        }
    }
}

enum IconProcessingService {
    static func transparentIconData(from url: URL) async throws -> Data {
        let sourceData = try Data(contentsOf: url)
        return try await Task.detached(priority: .userInitiated) {
            try makeTransparentPNG(from: sourceData)
        }.value
    }

    private static func makeTransparentPNG(from data: Data) throws -> Data {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw IconProcessingError.unreadableImage }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw IconProcessingError.foregroundNotFound
        }

        let mask = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )
        let sourceImage = CIImage(cgImage: image)
        let filter = CIFilter.blendWithMask()
        filter.inputImage = sourceImage
        filter.backgroundImage = CIImage(color: .clear).cropped(to: sourceImage.extent)
        filter.maskImage = CIImage(cvPixelBuffer: mask)

        guard
            let outputImage = filter.outputImage,
            let outputData = CIContext().pngRepresentation(
                of: outputImage,
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        else { throw IconProcessingError.exportFailed }

        return outputData
    }
}
