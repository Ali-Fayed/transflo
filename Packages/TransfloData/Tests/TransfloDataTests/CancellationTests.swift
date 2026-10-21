import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Cancelling long conversions", .enabled(if: MediaFixtures.hasFFmpeg))
struct CancellationTests {
    /// A 30-second 640×480 clip with sound; encoding it to WebM takes several seconds.
    private func longClip(in folder: URL) async throws -> URL {
        let clip = folder.appendingPathComponent("long clip.mp4")
        let status = await ProcessRunner.run(
            executable: try #require(MediaFixtures.ffmpeg),
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-y",
                        "-f", "lavfi", "-i", "testsrc=size=640x480:rate=30:duration=30",
                        "-f", "lavfi", "-i", "sine=frequency=440:duration=30", "-shortest",
                        "-c:v", "libvpx", "-b:v", "200k", "-deadline", "realtime", "-cpu-used", "8",
                        "-c:a", "libopus", clip.deletingPathExtension().appendingPathExtension("webm").path],
            onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        try #require(status == 0)
        let webm = clip.deletingPathExtension().appendingPathExtension("webm")
        let renamed = folder.appendingPathComponent("long clip source.webm")
        try FileManager.default.moveItem(at: webm, to: renamed)
        return renamed
    }

    @Test("cancelling an ffmpeg encode stops it within a second and leaves no partial file")
    func cancelsPromptly() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await longClip(in: folder.url)
        let target = try #require(MatrixConversionTests.catalog.format(FormatID("mkv")))
        let runner = MatrixConversionTests.makeRunner()
        // Untyped Task closure: typed throws inside `Task {}` mangles the error value.
        let task = Task { try await runner.run(WheelOption(.format(target)), on: [source]) { _ in } }
        try await Task.sleep(for: .milliseconds(700))
        let clock = ContinuousClock()
        let cancelled = clock.now
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("expected the job to be cancelled")
        } catch {
            #expect(error as? JobError == .cancelled)
        }
        #expect(clock.now - cancelled < .seconds(1))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: folder.url.path)
        #expect(leftovers == ["long clip source.webm"])
    }
}
