import CoreGraphics
import Foundation
import ImageIO
import TransfloDomain
import UniformTypeIdentifiers

/// Raster conversions, icons (ICO / ICNS) and image → PDF with Apple's ImageIO and Core Graphics.
///
/// Orientation is applied to the pixels (outputs are upright everywhere, including BMP and PDF),
/// metadata is otherwise carried over, and transparency is flattened onto white for formats
/// without alpha. Animated inputs use their first frame.
public struct ImageIOEngine: ConversionEngine {
    public let id = EngineIDs.imageIO

    static let readableFormats: Set<String> = [
        "jpg", "png", "heic", "tiff", "bmp", "webp", "avif", "gif", "ico", "icns"
    ]
    static let writeTypes: [String: String] = [
        "jpg": UTType.jpeg.identifier, "png": UTType.png.identifier, "heic": UTType.heic.identifier,
        "tiff": UTType.tiff.identifier, "bmp": UTType.bmp.identifier, "gif": UTType.gif.identifier,
        "avif": "public.avif", "ico": "com.microsoft.ico", "icns": "com.apple.icns"
    ]
    static let opaqueFormats: Set<String> = ["jpg", "bmp"]
    static let lossyQuality = 0.9

    private let systemWritableTypes: Set<String>

    public init() {
        systemWritableTypes = Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])
    }

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        guard Self.readableFormats.contains(source.id.rawValue) else { return false }
        if target.id.rawValue == "pdf" { return true }
        return Self.writeTypes[target.id.rawValue].map(systemWritableTypes.contains) ?? false
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        try await BlockingWork.run { () throws(JobError) in
            try convertSynchronously(request, progress: progress)
        }
        return [request.destination]
    }

    private func convertSynchronously(_ request: ConversionRequest, progress: (Double) -> Void) throws(JobError) {
        let decoded = try ImageDecoding.decodeUpright(request.source)
        progress(0.5)
        let target = request.targetFormat.id.rawValue
        if target == "pdf" {
            try PDFImageWriter.write(decoded.image, pointSize: decoded.pointSize, to: request.destination)
        } else {
            guard let type = Self.writeTypes[target] else { throw .unsupported }
            if IconFileWriter.sizes[target] != nil {
                try IconFileWriter.write(decoded.image, format: target, type: type, to: request.destination)
                progress(1)
                return
            }
            let image = Self.opaqueFormats.contains(target) ? try ImageDecoding.flattened(decoded.image) : decoded.image
            try write(image, properties: decoded.properties, type: type, to: request.destination)
        }
        progress(1)
    }

    private func write(_ image: CGImage, properties: [CFString: Any], type: String, to url: URL) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in
            try writeStaged(image, properties: properties, type: type, to: staged)
        }
    }

    private func writeStaged(
        _ image: CGImage,
        properties: [CFString: Any],
        type: String,
        to url: URL
    ) throws(JobError) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else {
            throw .destinationUnavailable
        }
        var options = properties
        options[kCGImagePropertyOrientation] = 1
        options[kCGImageDestinationLossyCompressionQuality] = Self.lossyQuality
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .failed }
    }
}
