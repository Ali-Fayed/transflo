import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

struct ArchiveFilesActionTests {
    @Test("Archive keeps every selected file and folder, including duplicate leaf names")
    func archiveSelection() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = folder.url.appendingPathComponent("first")
        let second = folder.url.appendingPathComponent("second")
        for directory in [first, second] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(directory.lastPathComponent.utf8).write(to: directory.appendingPathComponent("same.txt"))
        }
        let action = ArchiveFilesAction(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
        let items = [first.appendingPathComponent("same.txt"), second.appendingPathComponent("same.txt"), second]
        let output = try await action.perform(on: items, settings: nil)
        let names = try #require(await DocumentFixtures.entries(of: output[0]))
        #expect(names.contains("./same.txt") && names.contains("./same 2.txt"))
        #expect(names.contains("./second/same.txt"))
        let next = try await action.perform(on: items, settings: nil)
        #expect(next[0] != output[0])
        #expect(items.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }
}
