import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Moving files and recent folders")
struct FileMoverTests {
    private let checker = FileManagerExistenceChecker()
    private var sut: FileMover { FileMover(checker: checker, directories: checker) }

    @Test("files move into the folder under free names; files already there stay put")
    func moves() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let target = folder.url.appendingPathComponent("Target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let taken = target.appendingPathComponent("photo.jpg")
        try Data("old".utf8).write(to: taken)
        let photo = try folder.file("photo.jpg", contents: "new")
        let album = folder.url.appendingPathComponent("Album")
        try FileManager.default.createDirectory(at: album, withIntermediateDirectories: true)
        let moved = try await sut.move([photo, album, taken], to: target)
        #expect(moved.map(\.lastPathComponent) == ["photo 2.jpg", "Album", "photo.jpg"])
        #expect(try String(contentsOf: moved[0], encoding: .utf8) == "new")
        #expect(try String(contentsOf: taken, encoding: .utf8) == "old")
        #expect(!checker.fileExists(at: photo) && checker.isDirectory(at: moved[1]))
    }

    @Test("a folder can't move into itself; a missing or file destination is unavailable")
    func refusals() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let album = folder.url.appendingPathComponent("Album")
        let inner = album.appendingPathComponent("Inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        await #expect(throws: JobError.unsupported) { try await sut.move([album], to: inner) }
        await #expect(throws: JobError.unsupported) { try await sut.move([album], to: album) }
        let file = try folder.file("note.txt")
        await #expect(throws: JobError.destinationUnavailable) { try await sut.move([album], to: file) }
        let missing = folder.url.appendingPathComponent("Nope")
        await #expect(throws: JobError.destinationUnavailable) { try await sut.move([file], to: missing) }
        #expect(checker.isDirectory(at: inner))
    }

    @Test("a vanished source reports the missing file")
    func missingSource() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let gone = folder.url.appendingPathComponent("gone.txt")
        let target = folder.url.appendingPathComponent("T")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        await #expect(throws: JobError.sourceMissing) { try await sut.move([gone], to: target) }
    }

    @Test("recent folders round-trip through user defaults")
    func recents() throws {
        let suite = "transflo-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sut = UserDefaultsRecentFoldersRepository(defaults: defaults)
        #expect(sut.load().isEmpty)
        sut.save([URL(fileURLWithPath: "/Users/example/Projects"), URL(fileURLWithPath: "/Volumes/Disk")])
        #expect(sut.load().map(\.path) == ["/Users/example/Projects", "/Volumes/Disk"])
        #expect(sut.load().allSatisfy { $0.hasDirectoryPath })
    }
}
