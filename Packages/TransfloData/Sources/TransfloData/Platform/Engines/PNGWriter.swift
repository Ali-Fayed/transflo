import CoreGraphics
import Foundation
import ImageIO
import TransfloDomain
import UniformTypeIdentifiers

/// Writes a `CGImage` as PNG.
enum PNGWriter {
    static func write(_ image: CGImage, to url: URL) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in try writeStaged(image, to: staged) }
    }

    static func writeStaged(_ image: CGImage, to url: URL) throws(JobError) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw .destinationUnavailable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw .failed }
    }

    /// PNG bytes for `image`.
    static func data(_ image: CGImage) throws(JobError) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw .failed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw .failed }
        return data as Data
    }
}
