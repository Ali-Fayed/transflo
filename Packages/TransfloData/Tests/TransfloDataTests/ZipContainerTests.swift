import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Document ZIP safety")
struct ZipContainerTests {
    @Test("document containers cannot expose external files through symbolic links")
    func rejectsSymbolicLinks() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.cleanUp() }
        let manager = FileManager.default
        let outside = temporary.url.appendingPathComponent("outside.xml")
        try Data("<text>Private fixture</text>".utf8).write(to: outside)
        let source = temporary.url.appendingPathComponent("source")
        try manager.createDirectory(at: source, withIntermediateDirectories: true)
        try manager.createSymbolicLink(at: source.appendingPathComponent("chapter.xhtml"),
                                      withDestinationURL: outside)
        let archive = temporary.url.appendingPathComponent("linked.epub")
        let result = ProcessRunnerSync.run("/usr/bin/zip", ["-q", "-y", archive.path, "chapter.xhtml"], in: source)
        #expect(result?.status == 0)
        let destination = temporary.url.appendingPathComponent("extracted")
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        #expect(throws: JobError.failed) { try ZipArchiver.extract(archive, into: destination) }
        #expect(try String(contentsOf: outside, encoding: .utf8) == "<text>Private fixture</text>")
    }
}
