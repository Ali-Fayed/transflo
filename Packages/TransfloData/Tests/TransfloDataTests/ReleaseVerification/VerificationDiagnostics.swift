import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

/// Focused probes keep an output-success result separate from a feature's semantic correctness.
enum VerificationDiagnostics {
    static func run(root: URL, report: inout VerificationReport) async throws {
        let started = Date()
        let id = "edge-avi-2x-speed-five-seconds"
        do {
            let directory = try report.directory(id)
            let input = directory.appendingPathComponent("five-seconds.avi")
            let binary = try #require(MediaFixtures.ffmpeg)
            let status = await ProcessRunner.run(
                executable: binary,
                arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i",
                            "testsrc=size=128x96:rate=10:duration=5", "-f", "lavfi", "-i", "sine=duration=5",
                            "-c:v", "mpeg4", "-q:v", "4", "-c:a", "libmp3lame", "-shortest", input.path],
                onStdoutLine: { _ in }, onStderrLine: { _ in }
            )
            guard status == 0 else { throw VerificationSupport.Failure.fixtureUnavailable("five-second AVI") }
            let format = try #require(MatrixConversionTests.catalog.format(FormatID("avi")))
            let engine = MediaToolEngine(ffmpeg: binary, ffprobe: MediaFixtures.ffprobe, naming: MediaToolTests.naming)
            let request = ToolRequest(tool: .changeSpeed, settings: .changeSpeed(2),
                                      items: [ToolItem(url: input, format: format)])
            let outputs = try await engine.run(request) { _ in }
            let probe = try #require(MediaFixtures.ffprobe)
            let before = try await FFprobe.info(binary: probe, file: input).duration ?? 0
            let after = try await FFprobe.info(binary: probe, file: outputs[0]).duration ?? 0
            let correct = abs(after - before / 2) <= 0.15
            report.append(id, status: correct ? "PASS" : "FAIL",
                          detail: "Source \(before)s; 2× output \(after)s; expected \(before / 2)s ±0.15s",
                          outputs: outputs, started: started)
        } catch { report.append(id, error: error, started: started) }
        for format in ["ogg", "opus"] {
            try await metadataRoundTrip(format, report: &report)
        }
    }

    private static func metadataRoundTrip(_ format: String, report: inout VerificationReport) async throws {
        let id = "edge-\(format)-metadata-reader-roundtrip"
        let started = Date()
        let row = try #require(report.rows.first { $0.id == "tool-editMetadata-\(format)" })
        let directory = report.root.appendingPathComponent("results")
        let folders = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("tool-editMetadata-\(format)") }
        var result: URL?
        for folder in folders {
            result = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .first { $0.lastPathComponent.contains("editMetadata") }
            if result != nil { break }
        }
        guard let result else { throw VerificationSupport.Failure.fixtureUnavailable(row.id) }
        let descriptor = try #require(MatrixConversionTests.catalog.format(FormatID(format)))
        let reader = FileMetadataReader(ffprobe: MediaFixtures.ffprobe)
        let values = await reader.metadata(of: result, format: descriptor)
        let correct = values[.title] == "Transflo Verification" && values[.author] == "Test Fixture"
        report.append(id, status: correct ? "PASS" : "FAIL",
                      detail: "App metadata reader returns title/author: \(correct)",
                      outputs: [result], started: started)
    }
}
