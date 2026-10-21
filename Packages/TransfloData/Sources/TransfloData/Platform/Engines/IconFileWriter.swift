import CoreGraphics
import Foundation
import ImageIO
import TransfloDomain

/// Writes Windows (`.ico`) and macOS (`.icns`) icons: the image centered on a transparent square,
/// at every size the format's icon slots use.
enum IconFileWriter {
    /// Sizes per format. ImageIO's ICO writer takes at most six images; ICNS stores 1024 as 512 @2×.
    static let sizes: [String: [Int]] = [
        "ico": [16, 32, 48, 64, 128, 256],
        "icns": [16, 32, 128, 256, 512, 1024]
    ]

    static func write(_ image: CGImage, format: String, type: String, to url: URL) throws(JobError) {
        guard let sizes = sizes[format] else { throw .unsupported }
        try OutputFile.write(to: url) { staged throws(JobError) in
            guard let destination = CGImageDestinationCreateWithURL(staged as CFURL, type as CFString,
                                                                    sizes.count, nil) else {
                throw .destinationUnavailable
            }
            for size in sizes {
                CGImageDestinationAddImage(destination, try square(image, size: size), nil)
            }
            guard CGImageDestinationFinalize(destination) else { throw .failed }
        }
    }

    /// `image` scaled to fit a `size` × `size` transparent canvas, centered.
    static func square(_ image: CGImage, size: Int) throws(JobError) -> CGImage {
        guard image.width > 0, image.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw .failed }
        let scale = Double(size) / Double(max(image.width, image.height))
        let width = Double(image.width) * scale, height = Double(image.height) * scale
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (Double(size) - width) / 2, y: (Double(size) - height) / 2,
                                       width: width, height: height))
        guard let result = context.makeImage() else { throw .failed }
        return result
    }
}
