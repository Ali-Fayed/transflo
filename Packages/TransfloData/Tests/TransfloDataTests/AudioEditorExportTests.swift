import AVFoundation
import Foundation
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Audio editor exports", .enabled(if: MediaFixtures.hasFFmpeg))
struct AudioEditorExportTests {
    private let catalog = MatrixConversionTests.catalog
    private var engine: MediaToolEngine {
        MediaToolEngine(ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe, naming: MediaToolTests.naming)
    }
    private var inspector: ToolInspector {
        ToolInspector(formats: catalog, ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe)
    }
    private func run(_ tool: ToolKind, urls: [URL], settings: ToolSettings) async throws -> [URL] {
        try await engine.run(ToolRequest(tool: tool, settings: settings, items: urls.map {
            ToolItem(url: $0, format: catalog.format(forFileExtension: $0.pathExtension))
        })) { _ in }
    }
    private func make(_ filter: String, url: URL, extra: [String] = []) async throws {
        let status = await ProcessRunner.run(executable: try #require(MediaFixtures.ffmpeg),
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i", filter]
                + extra + [url.path], onStdoutLine: { _ in }, onStderrLine: { _ in })
        #expect(status == 0)
    }

    @Test("two-pass normalization reaches the requested loudness and preview is decodable")
    func loudness() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("quiet.wav")
        try await make("sine=frequency=440:duration=3", url: source)
        let target = LoudnessSettings(integrated: -18, truePeak: -2, range: 7)
        let output = try #require(try await run(.normalize, urls: [source], settings: .normalize(target)).first)
        let measured = try await inspector.loudness(of: output, settings: target)
        #expect(abs(measured.integrated - target.integrated) < 0.7)
        #expect(measured.truePeak <= target.truePeak + 0.3)
        let bytes = try await inspector.audioPreview(of: source, settings: .normalize(target))
        #expect(bytes.prefix(4) == Data("RIFF".utf8))
    }

    @Test("right-only exports the actual right channel, not a stereo average")
    func rightChannel() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("stereo.wav")
        try await make("aevalsrc=0.1*sin(2*PI*440*t)|0.1*sin(2*PI*880*t):s=48000:d=1", url: source)
        let output = try #require(try await run(.channels, urls: [source], settings: .channels(.right)).first)
        let file = try AVAudioFile(forReading: output)
        #expect(file.processingFormat.channelCount == 1)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 48000))
        try file.read(into: buffer)
        let samples = try #require(buffer.floatChannelData?[0])
        var crossings = 0
        for index in 1..<Int(buffer.frameLength) where samples[index - 1] <= 0 && samples[index] > 0 { crossings += 1 }
        #expect(abs(crossings - 880) <= 2)
    }

    @Test("shorter second clip rejects absolute timeline settings before the first export")
    func mismatchedDurations() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = folder.url.appendingPathComponent("long.wav")
        let second = folder.url.appendingPathComponent("short.wav")
        try await make("sine=duration=1", url: first)
        try await make("sine=duration=0.3", url: second)
        for settings in [ToolSettings.trim(start: 0, end: 0.8), .split(points: [0.5]), .snapshot(at: 0.8)] {
            let items = [first, second].map { ToolItem(url: $0, format: catalog.format(forFileExtension: "wav")) }
            await #expect(throws: JobError.incompatibleSelection) {
                try await ToolPreflight.media(items, settings: settings, ffprobe: MediaFixtures.ffprobe)
            }
        }
        await #expect(throws: JobError.incompatibleSelection) {
            _ = try await run(.trim, urls: [first, second], settings: .trim(start: 0, end: 0.8))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path).count == 2)
    }

    @Test("right-only rejects mono input and silence has no finite normalization measurement")
    func invalidAudioSelections() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let mono = folder.url.appendingPathComponent("mono.wav")
        let silence = folder.url.appendingPathComponent("silence.wav")
        try await make("sine=duration=1", url: mono)
        try await make("anullsrc=r=48000:cl=stereo", url: silence, extra: ["-t", "1"])
        await #expect(throws: JobError.incompatibleSelection) {
            _ = try await run(.channels, urls: [mono], settings: .channels(.right))
        }
        await #expect(throws: JobError.nothingFound) {
            _ = try await inspector.loudness(of: silence, settings: LoudnessSettings())
        }
    }
}
