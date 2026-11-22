import Foundation
import UIKit

struct PreparedGarmentImage: Sendable {
    let main: Data
    let thumbnail: Data
}

enum GarmentImageError: LocalizedError {
    case unreadableImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "This photo could not be read."
        case .encodingFailed: "This photo could not be processed."
        }
    }
}

enum GarmentImageProcessor {
    static func prepare(_ data: Data) throws -> PreparedGarmentImage {
        guard let image = UIImage(data: data) else {
            throw GarmentImageError.unreadableImage
        }
        guard
            let main = jpegData(from: image, maxDimension: 2_048, quality: 0.86),
            let thumbnail = jpegData(from: image, maxDimension: 600, quality: 0.8)
        else {
            throw GarmentImageError.encodingFailed
        }
        return PreparedGarmentImage(main: main, thumbnail: thumbnail)
    }

    private static func jpegData(
        from source: UIImage,
        maxDimension: CGFloat,
        quality: CGFloat
    ) -> Data? {
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return nil
        }

        let longestSide = max(sourceSize.width, sourceSize.height)
        let scale = min(1, maxDimension / longestSide)
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
