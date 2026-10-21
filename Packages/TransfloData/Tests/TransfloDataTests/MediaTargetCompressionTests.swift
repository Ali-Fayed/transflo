import Foundation
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite(.enabled(if: MediaFixtures.hasFFmpeg))
struct MediaTargetCompressionTests {
    @Test func twoPassVideoHonorsBudgetAndKeepsAudio() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let binary = try #require(MediaFixtures.ffmpeg)
        let source = folder.url.appendingPathComponent("source.mp4")
        let status = await ProcessRunner.run(executable: binary, arguments: [
            "-hide_banner", "-nostdin", "-loglevel", "error", "-n", "-f", "lavfi", "-i",
            "testsrc2=size=320x240:rate=24:duration=3", "-f", "lavfi", "-i", "sine=duration=3",
            "-c:v", "mpeg4", "-q:v", "2", "-c:a", "aac", "-b:a", "192k", source.path
        ], onStdoutLine: { _ in }, onStderrLine: { _ in })
        #expect(status == 0)
        let bytes = try #require(source.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        let budget = Int64(bytes * 2 / 3)
        let output = try await run(source, budget: budget)
        #expect(try Data(contentsOf: output).count <= budget)
        let info = try await FFprobe.info(binary: try #require(MediaFixtures.ffprobe), file: output)
        #expect(info.hasVideo && info.hasAudio)
    }

    @Test func audioBudgetAndSmallOriginalCopy() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("mp3", into: folder.url)
        let original = try Data(contentsOf: source)
        let copied = try await run(source, budget: Int64(original.count + 1))
        #expect(try Data(contentsOf: copied) == original)
        let budget = Int64(original.count * 3 / 4)
        let compressed = try await run(source, budget: budget)
        #expect(try Data(contentsOf: compressed).count <= budget)
    }

    @Test func impossibleMediaBudgetLeavesOnlyTheOriginal() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("mp3", into: folder.url)
        await #expect(throws: JobError.targetUnreachable) { try await run(source, budget: 1) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path).count == 1)
    }

    private func run(_ source: URL, budget: Int64) async throws -> URL {
        let naming = ToolOutputNaming(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()),
                                       suffixes: StubToolSuffixes())
        let engine = MediaToolEngine(ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe, naming: naming)
        let format = MatrixConversionTests.catalog.format(forFileExtension: source.pathExtension)
        let request = ToolRequest(tool: .compress, settings: .compress(.targetBytes(budget)),
                                  items: [ToolItem(url: source, format: format)])
        return try #require(await engine.run(request) { _ in }.first)
    }
}
