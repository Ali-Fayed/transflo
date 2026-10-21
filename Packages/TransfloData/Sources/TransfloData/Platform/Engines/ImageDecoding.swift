import CoreGraphics
import Foundation
import ImageIO
import TransfloDomain

/// Decodes the first frame of an image file, upright, with its metadata.
enum ImageDecoding {
    struct Decoded {
        let image: CGImage
        let properties: [CFString: Any]
        /// Physical size in points at the image's DPI (72 when unknown).
        let pointSize: CGSize
    }

    static func decodeUpright(_ url: URL, longEdge: Int? = nil) throws(JobError) -> Decoded {
        guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw .failed
        }
        guard width > 0, height > 0 else { throw .failed }
        let edge = min(max(width, height), longEdge ?? max(width, height))
        guard edge > 0 else { throw .failed }
        let ratio = Double(edge) / Double(max(width, height))
        guard RasterLimits.allows(CGSize(width: max(1, Double(width) * ratio),
                                        height: max(1, Double(height) * ratio))) else { throw .failed }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: edge,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw .failed }
        let dpi = (properties[kCGImagePropertyDPIWidth] as? Double).flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 72
        let scale = 72 / dpi
        return Decoded(
            image: image,
            properties: properties,
            pointSize: CGSize(width: Double(image.width) * scale, height: Double(image.height) * scale)
        )
    }

    /// Composites `image` over white so formats without alpha do not turn transparency black.
    static func flattened(_ image: CGImage) throws(JobError) -> CGImage {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return image
        default:
            break
        }
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw .failed
        }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.draw(image, in: bounds)
        guard let result = context.makeImage() else { throw .failed }
        return result
    }
}
