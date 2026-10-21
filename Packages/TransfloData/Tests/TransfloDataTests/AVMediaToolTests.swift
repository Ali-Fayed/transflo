@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Native media tools")
struct AVMediaToolTests {
    private let catalog = MatrixConversionTests.catalog
    private let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("avmedia-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private var engine: AVMediaToolEngine {
        let files = NameOutputFileUseCase(checker: FileManagerExistenceChecker())
        return AVMediaToolEngine(naming: ToolOutputNaming(naming: files, suffixes: StubToolSuffixes()))
    }

    private func item(_ url: URL) -> ToolItem {
        ToolItem(url: url, format: catalog.format(forFileExtension: url.pathExtension))
    }

    private func run(_ tool: ToolKind, _ urls: [URL], _ settings: ToolSettings) async throws -> [URL] {
        try await engine.run(ToolRequest(tool: tool, settings: settings, items: urls.map(item))) { _ in }
    }

    private func duration(_ url: URL) async throws -> Double {
        try await AVURLAsset(url: url).load(.duration).seconds
    }

    private func tracks(_ url: URL, _ type: AVMediaType) async throws -> Int {
        try await AVURLAsset(url: url).loadTracks(withMediaType: type).count
    }

    // MARK: Availability (no media needed)

    @Test("tools accept only the formats Apple's frameworks read")
    func availability() throws {
        let mp4 = catalog.format(forFileExtension: "mp4"), m4a = catalog.format(forFileExtension: "m4a")
        let mkv = catalog.format(forFileExtension: "mkv")
        #expect(engine.canRun(.trim, on: [mp4]) && engine.canRun(.trim, on: [m4a]))
        #expect(engine.canRun(.mute, on: [mp4]) && !engine.canRun(.mute, on: [m4a]))
        #expect(!engine.canRun(.snapshot, on: [m4a]) && !engine.canRun(.trim, on: [mkv]))
        #expect(engine.canRun(.merge, on: [mp4, mp4]) && !engine.canRun(.merge, on: [mp4]))
        #expect(!engine.canRun(.merge, on: [mp4, m4a]) && !engine.canRun(.compress, on: [mp4]))
    }

    @Test("split points become consecutive parts, dropping slivers and points outside the clip")
    func parts() {
        #expect(AVMediaComposer.parts(splitting: 10, at: [4, 2, 12, -1]) == [0...2, 2...4, 4...10])
        #expect(AVMediaComposer.parts(splitting: 1, at: [0.95]) == [0...0.95])
    }

    @Test("a range too short to export is refused")
    func shortRange() {
        #expect(throws: JobError.incompatibleSelection) {
            try AVMediaComposer.timeRange(0.5...0.55, within: CMTime(seconds: 10, preferredTimescale: 600))
        }
    }

    @Test("a missing file is reported")
    func missing() async {
        await #expect(throws: JobError.sourceMissing) {
            try await run(.trim, [folder.appendingPathComponent("gone.mp4")], .trim(start: 0, end: 1))
        }
    }

    // MARK: Real media (needs the bundled ffmpeg to make fixtures)

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func trimShortensAndKeepsTheContainer() async throws {
        let clip = try await MediaFixtures.make("mp4", in: folder)
        let output = try #require(try await run(.trim, [clip], .trim(start: 0.2, end: 0.7)).first)
        let length = try await duration(output)
        #expect(output.pathExtension == "mp4")
        #expect(abs(length - 0.5) < 0.2)
        #expect(FileManager.default.fileExists(atPath: clip.path))
    }

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func muteDropsTheSoundtrack() async throws {
        let clip = try await MediaFixtures.make("mp4", in: folder)
        let output = try #require(try await run(.mute, [clip], .none).first)
        let audio = try await tracks(output, .audio), video = try await tracks(output, .video)
        #expect(audio == 0 && video == 1)
    }

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func doubleSpeedHalvesTheLength() async throws {
        let clip = try await MediaFixtures.make("mp4", in: folder)
        let output = try #require(try await run(.changeSpeed, [clip], .changeSpeed(2)).first)
        let fast = try await duration(output), original = try await duration(clip)
        #expect(abs(fast - original / 2) < 0.2)
    }

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func snapshotWritesAFrame() async throws {
        let clip = try await MediaFixtures.make("mp4", in: folder)
        let png = try #require(try await run(.snapshot, [clip], .snapshot(at: 0.5)).first)
        let jpeg = try #require(try await run(.snapshot, [clip], .snapshotJPEG(at: 9, quality: 80)).first)
        #expect(png.pathExtension == "png" && jpeg.pathExtension == "jpg")
        let source = try #require(CGImageSourceCreateWithURL(png as CFURL, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        #expect(properties?[kCGImagePropertyPixelWidth] as? Int == 128)
    }

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func splitAndMerge() async throws {
        let clip = try await MediaFixtures.make("mp4", in: folder)
        let parts = try await run(.split, [clip], .split(points: [0.5]))
        #expect(parts.count == 2)
        let merged = try #require(try await run(.merge, [clip, clip], .none).first)
        let total = try await duration(merged), single = try await duration(clip)
        #expect(abs(total - 2 * single) < 0.3)
        await #expect(throws: JobError.incompatibleSelection) {
            try await run(.split, [clip], .split(points: [5]))
        }
    }

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func audioIsWrittenAsM4A() async throws {
        let song = try await MediaFixtures.make("wav", in: folder)
        let output = try #require(try await run(.trim, [song], .trim(start: 0, end: 0.5)).first)
        let audio = try await tracks(output, .audio)
        #expect(output.pathExtension == "m4a" && audio == 1)
    }

    // MARK: Conversions

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func extractsTheSoundtrackAndMakesAGIF() async throws {
        let clip = try await MediaFixtures.make("mp4", in: folder)
        let engine = AVFoundationEngine()
        let mp4 = try #require(catalog.format(forFileExtension: "mp4"))
        let m4a = try #require(catalog.format(forFileExtension: "m4a"))
        let gifFormat = try #require(catalog.format(forFileExtension: "gif"))
        let audio = folder.appendingPathComponent("sound.m4a"), gif = folder.appendingPathComponent("clip.gif")
        _ = try await engine.convert(ConversionRequest(source: clip, destination: audio, sourceFormat: mp4,
                                                       targetFormat: m4a)) { _ in }
        _ = try await engine.convert(ConversionRequest(source: clip, destination: gif, sourceFormat: mp4,
                                                       targetFormat: gifFormat)) { _ in }
        let soundtrack = try await tracks(audio, .audio)
        #expect(soundtrack == 1)
        let frames = CGImageSourceCreateWithURL(gif as CFURL, nil).map(CGImageSourceGetCount) ?? 0
        #expect(frames > 1)
    }

    @Test("GIF frame times are evenly spaced and capped")
    func gifFrames() {
        #expect(VideoGIFWriter.frameTimes(duration: 1).count == 12)
        #expect(VideoGIFWriter.frameTimes(duration: 600).count == VideoGIFWriter.maximumFrames)
    }
}
