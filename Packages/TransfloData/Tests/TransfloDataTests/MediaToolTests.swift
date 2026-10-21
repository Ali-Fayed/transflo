import Foundation
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Media tools", .enabled(if: MediaFixtures.hasFFmpeg))
struct MediaToolTests {
    private let catalog = MatrixConversionTests.catalog
    private var engine: MediaToolEngine {
        MediaToolEngine(ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe, naming: Self.naming)
    }

    static let naming = ToolOutputNaming(
        naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()), suffixes: StubToolSuffixes()
    )

    private func run(_ tool: ToolKind, _ urls: [URL], settings: ToolSettings? = nil) async throws -> [URL] {
        let items = urls.map { ToolItem(url: $0, format: catalog.format(forFileExtension: $0.pathExtension)) }
        let request = ToolRequest(tool: tool, settings: settings ?? .defaults(for: tool), items: items)
        return try await engine.run(request) { _ in }
    }

    private func probe(_ url: URL) async throws -> MediaInfo {
        try await FFprobe.info(binary: try #require(MediaFixtures.ffprobe), file: url)
    }

    /// Runs the test ffmpeg to make a custom fixture.
    private func ffmpeg(_ arguments: [String]) async throws {
        let status = await ProcessRunner.run(
            executable: try #require(MediaFixtures.ffmpeg),
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-y"] + arguments,
            onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        #expect(status == 0)
    }

    @Test("compress keeps a playable file in the same format", arguments: ["mp4", "mov", "webm", "mp3", "m4a", "opus"])
    func compress(format: String) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let outputs = try await run(.compress, [try await FixtureCache.shared.copy(format, into: folder.url)])
        #expect(outputs.map(\.lastPathComponent) == ["source (compress).\(format)"])
        let info = try await probe(outputs[0])
        #expect(info.hasAudio)
        #expect((info.duration ?? 0) > 0.5)
    }

    @Test("rotate turns video a quarter clockwise; flips keep the frame size")
    func rotate() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("mp4", into: folder.url)
        let turned = try await probe(try await run(.rotate, [source])[0])
        #expect(turned.width == 96 && turned.height == 128)
        let mirror = ToolSettings.rotate(quarterTurns: 0, flipHorizontal: true, flipVertical: false)
        let flipped = try await probe(try await run(.rotate, [source], settings: mirror)[0])
        #expect(flipped.width == 128 && flipped.height == 96)
    }

    @Test("mute drops audio and keeps video")
    func mute() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("mp4", into: folder.url)
        let info = try await probe(try await run(.mute, [source])[0])
        #expect(info.hasVideo && !info.hasAudio)
    }

    @Test("normalize keeps the streams", arguments: ["mp3", "wav", "mp4"])
    func normalize(format: String) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy(format, into: folder.url)
        let info = try await probe(try await run(.normalize, [source])[0])
        #expect(info.hasAudio)
        #expect(info.hasVideo == (format == "mp4"))
    }

    @Test("mono folds stereo to one channel")
    func mono() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let stereo = folder.url.appendingPathComponent("stereo.wav")
        try await ffmpeg(["-f", "lavfi", "-i", "sine=duration=1", "-ac", "2", stereo.path])
        #expect(try await probe(stereo).audioChannels == 2)
        #expect(try await probe(try await run(.channels, [stereo])[0]).audioChannels == 1)
    }

    @Test("remove metadata clears container tags")
    func stripTags() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let tagged = folder.url.appendingPathComponent("tagged.mp3")
        try await ffmpeg(["-f", "lavfi", "-i", "sine=duration=1", "-metadata", "title=Secret", "-c:a", "libmp3lame",
                          tagged.path])
        #expect(try await probe(tagged).tags["title"] == "Secret")
        #expect(try await probe(try await run(.removeMetadata, [tagged])[0]).tags["title"] == nil)
    }

    @Test("merge joins clips end to end, filling silence for clips without sound")
    func mergeVideo() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = try await FixtureCache.shared.copy("mp4", into: folder.url)
        let silent = try await run(.mute, [first])[0]
        let merged = try await run(.merge, [first, silent])
        #expect(merged.map(\.lastPathComponent) == ["source (merge).mp4"])
        let info = try await probe(merged[0])
        #expect(info.hasVideo && info.hasAudio)
        #expect(abs((info.duration ?? 0) - 2) < 0.3)
    }

    @Test("audio files merge into the first file's format")
    func mergeAudio() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let mp3 = try await FixtureCache.shared.copy("mp3", into: folder.url)
        let wav = try await FixtureCache.shared.copy("wav", into: folder.url)
        let merged = try await run(.merge, [mp3, wav])
        #expect(merged[0].pathExtension == "mp3")
        #expect(abs((try await probe(merged[0]).duration ?? 0) - 2) < 0.3)
    }

    @Test("capabilities follow formats, counts and helpers")
    func capabilities() {
        let mp4 = catalog.format(FormatID("mp4"))
        let mp3 = catalog.format(FormatID("mp3"))
        let wav = catalog.format(FormatID("wav"))
        #expect(engine.canRun(.mute, on: [mp4]))
        #expect(!engine.canRun(.mute, on: [mp3]))
        #expect(!engine.canRun(.compress, on: [wav]))
        #expect(engine.canRun(.channels, on: [wav]))
        #expect(!engine.canRun(.merge, on: [mp4]))
        #expect(!engine.canRun(.merge, on: [mp4, mp3]))
        #expect(engine.canRun(.merge, on: [mp3, wav]))
        #expect(!engine.canRun(.annotate, on: [mp4]))
        #expect(!MediaToolEngine(ffmpeg: nil, ffprobe: nil, naming: Self.naming).canRun(.mute, on: [mp4]))
    }

    @Test("a missing source fails without leaving output")
    func missing() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let ghost = folder.url.appendingPathComponent("ghost.mp4")
        await #expect(throws: JobError.sourceMissing) { _ = try await run(.mute, [ghost]) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path).isEmpty)
    }
}

@Suite("Media tool arguments")
struct MediaToolArgumentTests {
    @Test("ffprobe JSON parses streams, duration, frame rate and tags")
    func parsesProbe() throws {
        let json = #"{"streams":[{"codec_type":"video","width":640,"height":360,"avg_frame_rate":"30000/1001"},"#
            + #"{"codec_type":"audio","channels":2}],"format":{"duration":"12.5","tags":{"TITLE":"x"}}}"#
        let info = try FFprobe.parse(Data(json.utf8))
        #expect(info == MediaInfo(duration: 12.5, width: 640, height: 360, hasVideo: true, hasAudio: true,
                                  audioChannels: 2, frameRate: 30000.0 / 1001, tags: ["title": "x"]))
        #expect(FFprobe.frameRate("0/0") == nil)
        #expect(throws: JobError.failed) { try FFprobe.parse(Data("nope".utf8)) }
    }

    @Test("video filters merge into an existing chain")
    func filters() {
        #expect(FFmpegToolArguments.mergingVideoFilters(["hflip"], into: ["-vf", "scale=2:2", "-c:v", "x"])
            == ["-vf", "hflip,scale=2:2", "-c:v", "x"])
        let added = FFmpegToolArguments.mergingVideoFilters(["hflip"], into: ["-c:v", "x"])
        #expect(added == ["-c:v", "x", "-vf", "hflip"])
        #expect(FFmpegToolArguments.withoutVideoFilters(["-a", "-vf", "s", "-b"]) == ["-a", "-b"])
    }

    @Test("merge plans add silence only where needed")
    func mergePlan() throws {
        let sound = MediaInfo(duration: 1, width: 641, height: 361, hasVideo: true, hasAudio: true,
                              audioChannels: 2, frameRate: 25, tags: [:])
        let silent = MediaInfo(duration: 2, width: 320, height: 240, hasVideo: true, hasAudio: false,
                               audioChannels: nil, frameRate: 30, tags: [:])
        let inputs = [("/a.mp4", sound), ("/b.mp4", silent)]
        let arguments = try #require(MergePlan.arguments(inputs: inputs, format: "mp4"))
        let graph = try #require(arguments.firstIndex(of: "-filter_complex").map { arguments[$0 + 1] })
        #expect(arguments.filter { $0 == "anullsrc=r=48000:cl=stereo" }.count == 1)
        #expect(graph.contains("[2:a]aresample"))
        #expect(graph.contains("scale=640:360"))
        #expect(graph.hasSuffix("concat=n=2:v=1:a=1[v][a]"))
        #expect(!arguments.contains("-vf"))
        #expect(MergePlan.arguments(inputs: [("/a.mp4", sound)], format: "mp4") == nil)
    }
}
