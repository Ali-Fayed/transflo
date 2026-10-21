import CoreGraphics
import Foundation
import TransfloDomain

/// Compress for images: lossy formats re-encode at a lower quality; PNG is palette-quantized
/// (256 colors, dithered) with ffmpeg; TIFF switches to LZW. Strong also caps the long edge.
enum ImageCompressor {
    static let compressible: Set<String> = ["jpg", "heic", "avif", "webp", "png", "tiff"]
    static let strongLongEdge = 2560

    static func quality(for level: CompressionLevel) -> Double {
        switch level {
        case .light: 0.75
        case .medium: 0.6
        case .strong: 0.45
        }
    }

    static func compress(
        _ source: URL,
        format: String,
        level: CompressionLevel,
        writer: ImageFileWriter,
        to output: URL,
        maximumLongEdge: Int? = nil,
        usesPresetSize: Bool = true
    ) throws(JobError) {
        var decoded = try ImageDecoding.decodeUpright(source)
        let edge = maximumLongEdge ?? (usesPresetSize && level == .strong ? strongLongEdge : nil)
        if let edge, let smaller = ImageScaling.fit(decoded.image, longEdge: edge) {
            decoded = ImageDecoding.Decoded(
                image: smaller, properties: decoded.properties, pointSize: decoded.pointSize
            )
        }
        if format == "png", let ffmpeg = writer.ffmpeg {
            try quantizePNG(decoded.image, ffmpeg: ffmpeg, to: output)
        } else {
            try writer.write(
                decoded.image, format: format, quality: quality(for: level), properties: decoded.properties, to: output
            )
        }
    }

    static func quantizePNG(_ image: CGImage, ffmpeg: URL, to output: URL) throws(JobError) {
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let input = workspace.url.appendingPathComponent("in.png")
        try PNGWriter.write(image, to: input)
        let filter = "split[a][b];[a]palettegen=max_colors=256:reserve_transparent=1[p];"
            + "[b][p]paletteuse=dither=sierra2_4a"
        let arguments = ["-hide_banner", "-nostdin", "-loglevel", "error", "-n", "-i", input.path,
                         "-vf", filter, "-frames:v", "1", "-update", "1", output.path]
        #if os(macOS)
        guard ProcessRunnerSync.run(ffmpeg.path, arguments)?.status == 0 else { throw .failed }
        #else
        throw .unsupported
        #endif
    }
}
