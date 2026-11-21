import CoreImage
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

        let maskedImage = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )

        guard let outputData = CIContext().pngRepresentation(
            of: CIImage(cvPixelBuffer: maskedImage),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        ) else { throw IconProcessingError.exportFailed }

        return outputData
    }
}
