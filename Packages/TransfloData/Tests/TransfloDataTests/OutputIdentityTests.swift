import Foundation
import Testing
@testable import TransfloData

@Suite("Output identity")
struct OutputIdentityTests {
    @Test func publicationOwnershipDoesNotFollowReplacementPaths() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("identity-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let staged = folder.appendingPathComponent("staged")
        let output = folder.appendingPathComponent("result.png")
        try Data([1]).write(to: staged)
        try ToolOutputPublisher.publish(staged, to: output, isCancelled: { false })
        #expect(OutputProvenance.shared.contains(output))
        let saved = try #require(FileArtifactIdentity.fingerprint(output))
        try FileManager.default.removeItem(at: output)
        try Data([1]).write(to: output)
        #expect(FileArtifactIdentity.fingerprint(output) != saved)
        #expect(!OutputProvenance.shared.contains(output))
    }

    @Test func changingAChildInvalidatesADirectorySnapshot() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("identity-dir-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("page.png")
        try Data([1]).write(to: file)
        let saved = try #require(FileArtifactIdentity.fingerprint(folder))
        try Data([2, 3]).write(to: file)
        #expect(FileArtifactIdentity.fingerprint(folder) != saved)
    }
}
