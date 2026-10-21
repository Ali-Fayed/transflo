import CoreGraphics
import Foundation
import ImageIO
import TransfloDomain
import UniformTypeIdentifiers

/// Writes a `CGImage` in a given image format: ImageIO where macOS can encode it, the bundled
/// ffmpeg for WebP.
struct ImageFileWriter {
    let ffmpeg: URL?
    private static let writableTypes = Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])

    func canWrite(_ format: String) -> Bool {
        if format == "webp" { return ffmpeg != nil }
        return ImageIOEngine.writeTypes[format].map(Self.writableTypes.contains) ?? false
    }

    /// - Parameters:
    ///   - quality: Lossy quality 0...1 (ignored by lossless formats).
    ///   - properties: Metadata to keep; pass `[:]` to strip everything.
    func write(
        _ image: CGImage,
        format: String,
        quality: Double = 0.9,
        properties: [CFString: Any] = [:],
        to url: URL
    ) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in
            try writeStaged(image, format: format, quality: quality, properties: properties, to: staged)
        }
    }

    private func writeStaged(
        _ image: CGImage,
        format: String,
        quality: Double = 0.9,
        properties: [CFString: Any] = [:],
        to url: URL
    ) throws(JobError) {
        if format == "webp" {
            try writeWebP(image, quality: quality, to: url)
            return
        }
        guard let type = ImageIOEngine.writeTypes[format],
              let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil)
        else { throw .destinationUnavailable }
        var options = properties
        options[kCGImagePropertyOrientation] = 1
        options[kCGImageDestinationLossyCompressionQuality] = quality
        if format == "tiff" {
            var tiff = options[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
            tiff[kCGImagePropertyTIFFCompression] = 5
            options[kCGImagePropertyTIFFDictionary] = tiff
        }
        let pixels = ImageIOEngine.opaqueFormats.contains(format) ? try ImageDecoding.flattened(image) : image
        CGImageDestinationAddImage(destination, pixels, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .failed }
    }

    private func writeWebP(_ image: CGImage, quality: Double, to url: URL) throws(JobError) {
        guard let ffmpeg else { throw .unsupported }
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let png = workspace.url.appendingPathComponent("frame.png")
        try PNGWriter.write(image, to: png)
        let arguments = ["-hide_banner", "-nostdin", "-loglevel", "error", "-n", "-i", png.path,
                         "-c:v", "libwebp", "-quality", String(Int(quality * 100)), url.path]
        #if os(macOS)
        guard ProcessRunnerSync.run(ffmpeg.path, arguments)?.status == 0 else { throw .failed }
        #else
        throw .unsupported
        #endif
    }
}
