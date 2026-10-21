import CoreGraphics
import Foundation
import TransfloDomain

/// ImageEncoding Strategy using the same writers as ordinary image edits.
struct TargetImageEncoder: ImageEncoding {
    let decoded: ImageDecoding.Decoded
    let format: String
    let writer: ImageFileWriter
    let workspace: URL

    var supportsQualitySearch: Bool { !["png", "tiff"].contains(format) }

    func encode(quality: Double, scale: Double) throws(JobError) -> Data {
        let edge = max(1, Int(Double(max(decoded.image.width, decoded.image.height)) * scale))
        let image = ImageScaling.fit(decoded.image, longEdge: edge) ?? decoded.image
        let output = workspace.appendingPathComponent(UUID().uuidString).appendingPathExtension(format)
        defer { try? FileManager.default.removeItem(at: output) }
        if !supportsQualitySearch, let ffmpeg = writer.ffmpeg {
            let palette = workspace.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
            defer { try? FileManager.default.removeItem(at: palette) }
            try ImageCompressor.quantizePNG(image, ffmpeg: ffmpeg, to: palette)
            if format == "png" {
                do { return try Data(contentsOf: palette) } catch { throw .failed }
            }
            let quantized = try ImageDecoding.decodeUpright(palette).image
            try writer.write(quantized, format: format, properties: decoded.properties, to: output)
        } else {
            try writer.write(image, format: format, quality: quality, properties: decoded.properties, to: output)
        }
        do { return try Data(contentsOf: output) } catch { throw .failed }
    }
}
