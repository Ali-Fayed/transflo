import CoreGraphics
import Foundation
import ImageIO
@testable import TransfloData
import TransfloDomain
import UniformTypeIdentifiers

/// Generates small media files for conversion tests and verifies outputs.
enum MediaFixtures {
    /// The repo's locally built LGPL ffmpeg (`scripts/build-ffmpeg.sh`), if present.
    static let ffmpeg: URL? = vendorBinary("ffmpeg")
    static let ffprobe: URL? = vendorBinary("ffprobe")
    static var hasFFmpeg: Bool { ffmpeg != nil && ffprobe != nil }

    static let imageIOTypes: [String: UTType] = [
        "jpg": .jpeg, "png": .png, "heic": .heic, "tiff": .tiff, "bmp": .bmp, "gif": .gif,
        "avif": UTType("public.avif") ?? .image, "ico": .ico, "icns": .icns
    ]

    private static func vendorBinary(_ name: String) -> URL? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Vendor/ffmpeg/bin/\(name)")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    /// A 64×48 image with a transparent left half and an opaque gradient on the right.
    static func makeTestImage() -> CGImage? {
        guard let context = CGContext(
            data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: 64, height: 48))
        for column in 32..<64 {
            context.setFillColor(CGColor(srgbRed: Double(column) / 64, green: 0.4, blue: 0.6, alpha: 1))
            context.fill(CGRect(x: column, y: 0, width: 1, height: 48))
        }
        return context.makeImage()
    }

    static func writeImage(_ format: String, to url: URL, orientation: Int = 1) throws {
        guard let type = imageIOTypes[format], let image = makeTestImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
        else { throw FixtureError.cannotCreate(format) }
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError.cannotCreate(format) }
    }

    /// Creates `name.<format>` in `folder` and returns its URL.
    static func make(_ format: String, in folder: URL, name: String = "source") async throws -> URL {
        // Finder text clippings use the `.textClipping` extension, not the catalog id.
        let fileExtension = format == "clipping" ? "textClipping" : format
        let url = folder.appendingPathComponent("\(name).\(fileExtension)")
        switch format {
        case "svg":
            let svg = ##"<svg xmlns="http://www.w3.org/2000/svg" width="40" height="30"><rect width="40" height="30" fill="#136F63"/></svg>"##
            try Data(svg.utf8).write(to: url)
        case "ico", "icns":
            try await BlockingWork.run { () throws(JobError) in
                guard let image = makeTestImage(), let type = ImageIOEngine.writeTypes[format] else { throw .failed }
                try IconFileWriter.write(image, format: format, type: type, to: url)
            }
        case _ where DocumentFixtures.formats.contains(format):
            try await DocumentFixtures.make(format, at: url, in: folder)
        case _ where imageIOTypes[format] != nil && format != "gif":
            try await BlockingWork.run { () throws(JobError) in
                do { try writeImage(format, to: url) } catch { throw .failed }
            }
        default:
            try await makeWithFFmpeg(format, to: url, in: folder)
        }
        return url
    }

    private static func makeWithFFmpeg(_ format: String, to url: URL, in folder: URL) async throws {
        guard let ffmpeg, let output = FFmpegArguments.output(for: FormatID(format)) else {
            throw FixtureError.cannotCreate(format)
        }
        var inputs: [String]
        if format == "webp" {
            let png = folder.appendingPathComponent("fixture-\(UUID().uuidString).png")
            try writeImage("png", to: png)
            inputs = ["-i", png.path]
        } else {
            inputs = ["-f", "lavfi", "-i", "testsrc=size=128x96:rate=10:duration=1",
                      "-f", "lavfi", "-i", "sine=frequency=440:duration=1"]
            if format != "gif" { inputs += ["-shortest"] }
        }
        let errors = Collector()
        let status = await ProcessRunner.run(
            executable: ffmpeg,
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-y"] + inputs + output + [url.path],
            onStdoutLine: { _ in },
            onStderrLine: errors.append
        )
        guard status == 0 else {
            throw FixtureError.cannotCreate("\(format) (exit \(status.map(String.init) ?? "launch failed")): "
                + errors.lines.suffix(3).joined(separator: " | "))
        }
    }

    /// The container name ffprobe reports, e.g. `mov,mp4,m4a,3gp,3g2,mj2` or `matroska,webm`.
    static func probeContainer(_ url: URL) async -> String? {
        guard let ffprobe else { return nil }
        let collected = Collector()
        let status = await ProcessRunner.run(
            executable: ffprobe,
            arguments: ["-v", "error", "-show_entries", "format=format_name", "-of", "default=nw=1:nk=1", url.path],
            onStdoutLine: collected.append,
            onStderrLine: { _ in }
        )
        return status == 0 ? collected.lines.first : nil
    }

    /// Substring ffprobe's container name must contain for each output format.
    static let containerTokens: [String: String] = [
        "mp3": "mp3", "m4a": "mp4", "wav": "wav", "flac": "flac", "ogg": "ogg", "opus": "ogg",
        "aiff": "aiff", "wma": "asf", "mp4": "mp4", "mov": "mov", "mkv": "matroska", "webm": "webm",
        "avi": "avi", "wmv": "asf", "gif": "gif", "webp": "webp", "avif": "mp4"
    ]

    enum FixtureError: Error {
        case cannotCreate(String)
    }
}
