import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Archive extraction tool")
struct ArchiveExtractionTests {
    private var engine: ArchiveExtractionEngine {
        ArchiveExtractionEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
    }

    private func request(_ source: URL, format: String) -> ToolRequest {
        ToolRequest(tool: .extractArchive, settings: .none,
                    items: [ToolItem(url: source, format: SubtitleTests.format(format, family: .archive))])
    }

    private func archive(in folder: TemporaryDirectory, format: String) async throws -> URL {
        let payload = folder.url.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: payload.appendingPathComponent("hello.txt"))
        let source = folder.url.appendingPathComponent("bundle.\(format)")
        if format == "rar" {
            try RARFixture.archive(fileName: "hello.txt", contents: Data("hello".utf8)).write(to: source)
        } else {
            let flags = format == "gz" ? ["-czf"] : ["--format", format == "zip" ? "zip" : "pax", "-cf"]
            let status = await ProcessRunner.run(executable: DocumentFixtures.bsdtar,
                arguments: flags + [source.path, "-C", payload.path, "hello.txt"],
                onStdoutLine: { _ in }, onStderrLine: { _ in })
            #expect(status == 0)
        }
        return source
    }

    @Test("ZIP, TAR, GZIP tarballs and RAR extract into a new folder", arguments: ["zip", "tar", "gz", "rar"])
    func supported(format: String) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await archive(in: folder, format: format)
        let outputs = try await engine.run(request(source, format: format)) { _ in }
        #expect(outputs.count == 1 && outputs[0].lastPathComponent == "bundle")
        #expect(try String(contentsOf: outputs[0].appendingPathComponent("hello.txt"), encoding: .utf8) == "hello")
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test("single-file gzip and occupied output names preserve originals")
    func singleGzipAndCollision() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let plain = try folder.file("notes.txt", contents: "hello")
        _ = await ProcessRunner.run(executable: URL(fileURLWithPath: "/usr/bin/gzip"), arguments: ["-k", plain.path],
                                   onStdoutLine: { _ in }, onStderrLine: { _ in })
        let source = folder.url.appendingPathComponent("notes.txt.gz")
        let outputs = try await engine.run(request(source, format: "gz")) { _ in }
        #expect(outputs[0].lastPathComponent == "notes.txt 2")
        #expect(try String(contentsOf: outputs[0].appendingPathComponent("notes.txt"), encoding: .utf8) == "hello")
        #expect(try String(contentsOf: plain, encoding: .utf8) == "hello")
    }

    @Test("a failed batch reports earlier extracted folders and cleans scratch data")
    func partialBatch() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await archive(in: folder, format: "zip")
        let bad = try folder.file("bad.zip", contents: "not an archive")
        let items = [source, bad].map { ToolItem(url: $0, format: SubtitleTests.format("zip", family: .archive)) }
        do {
            _ = try await engine.run(ToolRequest(tool: .extractArchive, settings: .none, items: items)) { _ in }
            Issue.record("Corrupt input succeeded")
        } catch {
            #expect(error.completedOutputs.count == 1 && error.underlying == .failed)
            #expect(FileManager.default.fileExists(atPath: error.completedOutputs[0].path))
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.url.path)
        #expect(!names.contains("bad") && !names.contains { $0.hasPrefix(".transflo-") })
    }

    @Test("unsafe archive paths are rejected before publishing")
    func unsafePaths() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let inner = folder.url.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        _ = try folder.file("evil.txt")
        let source = folder.url.appendingPathComponent("slip.tar")
        _ = await ProcessRunner.run(executable: DocumentFixtures.bsdtar,
            arguments: ["-cf", source.path, "-C", inner.path, "-s", ",^,../,", "../evil.txt"],
            onStdoutLine: { _ in }, onStderrLine: { _ in })
        await #expect(throws: JobError.failed) { _ = try await engine.run(request(source, format: "tar")) { _ in } }
        #expect(!FileManager.default.fileExists(atPath: folder.url.appendingPathComponent("slip").path))
    }
}
