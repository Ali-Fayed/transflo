import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Engine behavior")
struct EngineBehaviorTests {
    private let png = FormatDescriptor(id: FormatID("png"), displayName: "PNG", extensions: ["png"], family: .image)
    private let jpg = FormatDescriptor(id: FormatID("jpg"), displayName: "JPG", extensions: ["jpg"], family: .image)
    private let wav = FormatDescriptor(id: FormatID("wav"), displayName: "WAV", extensions: ["wav"], family: .audio)

    private func request(
        _ source: URL,
        _ destination: URL,
        from: FormatDescriptor,
        to: FormatDescriptor
    ) -> ConversionRequest {
        ConversionRequest(source: source, destination: destination, sourceFormat: from, targetFormat: to)
    }

    @Test("JPG output flattens transparency onto white")
    func flattensAlpha() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await MediaFixtures.make("png", in: folder.url)
        let output = folder.url.appendingPathComponent("out.jpg")
        _ = try await ImageIOEngine().convert(request(source, output, from: png, to: jpg)) { _ in }
        let image = try #require(CGImageSourceCreateWithURL(output as CFURL, nil).flatMap {
            CGImageSourceCreateImageAtIndex($0, 0, nil)
        })
        // Sample the first pixel of the left (formerly transparent) half.
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixel = try #require(context.data?.assumingMemoryBound(to: UInt8.self))
        #expect(pixel[0] > 240 && pixel[1] > 240 && pixel[2] > 240, "transparent area should become white")
    }

    @Test("EXIF orientation is applied to the pixels")
    func appliesOrientation() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("rotated.jpg")
        try MediaFixtures.writeImage("jpg", to: source, orientation: 6)
        let output = folder.url.appendingPathComponent("upright.png")
        _ = try await ImageIOEngine().convert(request(source, output, from: jpg, to: png)) { _ in }
        let properties = try #require(CGImageSourceCreateWithURL(output as CFURL, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        })
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 48)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 64)
    }

    @Test("a corrupt image fails; a missing one reports sourceMissing")
    func badInputs() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let corrupt = try folder.file("broken.png", contents: "not an image")
        let output = folder.url.appendingPathComponent("out.jpg")
        await #expect(throws: JobError.failed) {
            _ = try await ImageIOEngine().convert(request(corrupt, output, from: png, to: jpg)) { _ in }
        }
        let missing = folder.url.appendingPathComponent("gone.png")
        await #expect(throws: JobError.sourceMissing) {
            _ = try await ImageIOEngine().convert(request(missing, output, from: png, to: jpg)) { _ in }
        }
    }

    @Test("an unwritable folder reports destinationUnavailable")
    func unwritable() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await MediaFixtures.make("png", in: folder.url)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.url.path)
        let output = folder.url.appendingPathComponent("out.jpg")
        await #expect(throws: JobError.destinationUnavailable) {
            _ = try await ImageIOEngine().convert(request(source, output, from: png, to: jpg)) { _ in }
        }
    }

    @Test("without a binary, ffmpeg offers nothing and refuses to run")
    func missingFFmpeg() async {
        let sut = FFmpegEngine(binary: nil)
        #expect(sut.canConvert(from: png, to: jpg) == false)
        let url = URL(fileURLWithPath: "/tmp/a.png")
        await #expect(throws: JobError.unsupported) {
            _ = try await sut.convert(request(url, url, from: png, to: jpg)) { _ in }
        }
    }

    @Test("a failing ffmpeg run reports failed", .enabled(if: MediaFixtures.hasFFmpeg))
    func ffmpegFailure() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let corrupt = try folder.file("broken.wav", contents: "RIFF garbage")
        let output = folder.url.appendingPathComponent("out.png")
        await #expect(throws: JobError.failed) {
            let engine = FFmpegEngine(binary: MediaFixtures.ffmpeg)
            _ = try await engine.convert(request(corrupt, output, from: wav, to: png)) { _ in }
        }
    }

    @Test("cancelling an ffmpeg job terminates it and reports cancelled", .enabled(if: MediaFixtures.hasFFmpeg))
    func ffmpegCancel() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await MediaFixtures.make("wav", in: folder.url)
        let output = folder.url.appendingPathComponent("out.flac")
        let flac = FormatDescriptor(id: FormatID("flac"), displayName: "FLAC", extensions: ["flac"], family: .audio)
        let task = Task {
            let engine = FFmpegEngine(binary: MediaFixtures.ffmpeg)
            _ = try await engine.convert(request(source, output, from: wav, to: flac)) { _ in }
        }
        task.cancel()
        let result = await task.result
        #expect(throws: JobError.cancelled) { try result.get() }
    }

    @Test("ffmpeg progress lines parse", arguments: [
        ("  Duration: 00:01:02.50, start: 0.000000, bitrate: 1411 kb/s", 62.5)
    ])
    func parsesDuration(line: String, seconds: Double) {
        #expect(FFmpegProgressParser.duration(fromStderrLine: line) == seconds)
    }

    @Test("ffmpeg progress values parse and reject junk")
    func parsesProgress() {
        #expect(FFmpegProgressParser.encodedSeconds(fromProgressLine: "out_time_us=2500000") == 2.5)
        #expect(FFmpegProgressParser.encodedSeconds(fromProgressLine: "out_time_ms=1000000") == 1)
        #expect(FFmpegProgressParser.encodedSeconds(fromProgressLine: "out_time_us=N/A") == nil)
        #expect(FFmpegProgressParser.encodedSeconds(fromProgressLine: "frame=10") == nil)
        #expect(FFmpegProgressParser.duration(fromStderrLine: "Duration: N/A, bitrate: N/A") == nil)
    }

    @Test("ffmpeg runs report every output line, including a final one without a newline",
          .enabled(if: MediaFixtures.hasFFmpeg))
    func streamsLines() async throws {
        let collected = Collector()
        let status = await ProcessRunner.run(
            executable: try #require(MediaFixtures.ffmpeg),
            arguments: ["-hide_banner", "-version"],
            onStdoutLine: collected.append,
            onStderrLine: { _ in }
        )
        #expect(status == 0)
        #expect(collected.lines.first?.hasPrefix("ffmpeg version") == true)
    }

    @Test("a missing executable reports a launch failure")
    func launchFailure() async {
        let status = await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/nonexistent/ffmpeg"),
            arguments: [],
            onStdoutLine: { _ in },
            onStderrLine: { _ in }
        )
        #expect(status == nil)
    }

    @Test("every ffmpeg-routed catalog target has encoder arguments")
    func argumentTable() throws {
        let catalog = try BundledCatalogLoader().load()
        let ffmpegTargets = Set(catalog.paths.filter { $0.engines.contains(EngineIDs.ffmpeg) }.map(\.target))
        #expect(ffmpegTargets.allSatisfy { FFmpegArguments.output(for: $0) != nil })
        #expect(FFmpegArguments.output(for: FormatID("heic")) == nil)
    }
}
