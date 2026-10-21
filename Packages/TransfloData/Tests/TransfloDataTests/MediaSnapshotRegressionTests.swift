import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Media snapshot regressions", .enabled(if: MediaFixtures.hasFFmpeg))
struct MediaSnapshotRegressionTests {
    private func makeVideo(in folder: TemporaryDirectory) async throws -> URL {
        let source = folder.url.appendingPathComponent("clip.mp4")
        let binary = try #require(MediaFixtures.ffmpeg)
        let status = await ProcessRunner.run(
            executable: binary,
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-n", "-f", "lavfi", "-i",
                         "testsrc=size=128x96:rate=4:duration=0.5", "-c:v", "mpeg4", "-an", source.path],
            onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        #expect(status == 0)
        return source
    }

    @Test("the endpoint produces a readable final frame in both the tool and its preview")
    func endpoint() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await makeVideo(in: folder)
        let probe = try #require(MediaFixtures.ffprobe)
        let duration = try #require(try await FFprobe.info(binary: probe, file: source).duration)
        let format = try #require(try BundledCatalogLoader().load().format(FormatID("mp4")))
        let engine = MediaToolEngine(ffmpeg: MediaFixtures.ffmpeg, ffprobe: probe, naming: MediaToolTests.naming)
        let request = ToolRequest(tool: .snapshot, settings: .snapshot(at: duration),
                                  items: [ToolItem(url: source, format: format)])
        let outputs = try await engine.run(request) { _ in }
        let output = try #require(outputs.first)
        let imageSource = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(image.width == 128 && image.height == 96)
        let provider = MediaToolPreviewProvider(ffmpeg: MediaFixtures.ffmpeg, ffprobe: probe)
        let preview = try #require(await provider.frame(of: source, at: duration))
        let previewSource = try #require(CGImageSourceCreateWithData(preview as CFData, nil))
        #expect(CGImageSourceCreateImageAtIndex(previewSource, 0, nil) != nil)
    }

    @Test("a crop of a rotated file fits the displayed frame")
    func rotatedCrop() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let original = try await makeVideo(in: folder)
        let binary = try #require(MediaFixtures.ffmpeg)
        let probe = try #require(MediaFixtures.ffprobe)
        let rotated = folder.url.appendingPathComponent("rotated.mp4")
        let status = await ProcessRunner.run(
            executable: binary,
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-n", "-display_rotation:v:0", "90",
                         "-i", original.path, "-c", "copy", rotated.path],
            onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        #expect(status == 0)
        let info = try await FFprobe.info(binary: probe, file: rotated)
        #expect(info.width == 96 && info.height == 128)
        let step = try #require(MediaEditArguments.crop(
            rotated.path, format: "mp4", rect: NormalizedRect(x: 0, y: 0, width: 1, height: 0.5), info: info
        ))
        let index = try #require(step.arguments.firstIndex(of: "-vf"))
        let output = folder.url.appendingPathComponent("crop.png")
        // PNG exercises the real crop filter without depending on hardware H.264 availability.
        try await FFmpegRunner.run(binary: binary, arguments: [
            "-i", rotated.path, "-vf", step.arguments[index + 1], "-frames:v", "1", "-update", "1", output.path
        ]) { _ in }
        let imageSource = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(image.width == 96 && image.height == 64)
    }
}
