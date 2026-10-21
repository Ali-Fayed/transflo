import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Bleep regressions", .enabled(if: MediaFixtures.hasFFmpeg))
struct BleepRegressionTests {
    @Test("bleep replaces every selected sample and preserves both channels outside overlapping spans")
    func sampleBoundaries() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let binary = try #require(MediaFixtures.ffmpeg)
        let rate = 48_000
        var original: [Int16] = []
        for index in 0..<rate {
            let time = Double(index) / Double(rate)
            original.append(Int16(8_000 * sin(2 * .pi * 440 * time)))
            original.append(Int16(6_000 * sin(2 * .pi * 660 * time)))
        }
        let raw = folder.url.appendingPathComponent("source.raw")
        try original.withUnsafeBytes { try Data($0).write(to: raw) }
        let source = folder.url.appendingPathComponent("source.wav")
        try await FFmpegRunner.run(binary: binary, arguments: [
            "-f", "s16le", "-ar", String(rate), "-ac", "2", "-i", raw.path, "-c:a", "pcm_s16le", source.path
        ]) { _ in }
        let spans = [TimeSpan(start: 0.180013, end: 0.500007), TimeSpan(start: 0.4, end: 0.55)]
        let engine = MediaToolEngine(ffmpeg: binary, ffprobe: MediaFixtures.ffprobe, naming: MediaToolTests.naming)
        let catalog = try BundledCatalogLoader().load()
        let request = ToolRequest(tool: .bleep, settings: .bleep(spans),
                                  items: [ToolItem(url: source, format: catalog.format(FormatID("wav")))])
        let output = try #require(try await engine.run(request) { _ in }.first)
        let decoded = folder.url.appendingPathComponent("output.raw")
        try await FFmpegRunner.run(binary: binary, arguments: [
            "-i", output.path, "-f", "s16le", "-c:a", "pcm_s16le", decoded.path
        ]) { _ in }
        let data = try Data(contentsOf: decoded)
        #expect(data.count == original.count * 2)
        let samples = data.withUnsafeBytes { bytes in
            (0..<(bytes.count / 2)).map {
                Int16(littleEndian: bytes.loadUnaligned(fromByteOffset: $0 * 2, as: Int16.self))
            }
        }
        var largestError = 0
        for index in 0..<min(rate, samples.count / 2) {
            let time = Double(index) / Double(rate)
            let selected = spans.contains { time >= $0.start && time <= $0.end }
            for channel in 0..<2 {
                let expected = selected ? Int(0.0375 * sin(2 * .pi * 1000 * time) * 32_768)
                    : Int(original[index * 2 + channel])
                largestError = max(largestError, abs(Int(samples[index * 2 + channel]) - expected))
            }
        }
        #expect(largestError <= 1)
    }
}
