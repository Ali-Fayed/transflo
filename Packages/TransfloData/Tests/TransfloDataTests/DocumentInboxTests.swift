import Foundation
import Testing
import TransfloData
import TransfloDomain

@Suite("Document inbox")
struct DocumentInboxTests {
    private let root: URL
    private let source: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
        root = base.appendingPathComponent("Documents")
        source = base.appendingPathComponent("Elsewhere")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    }

    private func file(_ name: String) throws -> URL {
        let url = source.appendingPathComponent(name)
        try Data(name.utf8).write(to: url)
        return url
    }

    private var fixedDate: Date { Date(timeIntervalSince1970: 1_800_000_000) }

    @Test("files are copied, in order, into one dated folder per import")
    func copies() throws {
        // Given two files elsewhere
        let photo = try file("photo.jpg"), notes = try file("notes.pdf")
        // When they're imported
        let copies = try DocumentInbox(root: root, now: { [fixedDate] in fixedDate }).importFiles([photo, notes])
        // Then both copies share a new folder and the originals stay put
        #expect(copies.map(\.lastPathComponent) == ["photo.jpg", "notes.pdf"])
        #expect(Set(copies.map { $0.deletingLastPathComponent() }).count == 1)
        #expect(copies[0].deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL
            == root.standardizedFileURL)
        #expect(try String(contentsOf: copies[1], encoding: .utf8) == "notes.pdf")
        #expect(FileManager.default.fileExists(atPath: photo.path))
    }

    @Test("a second import at the same moment gets its own folder")
    func separateFolders() throws {
        let inbox = DocumentInbox(root: root, now: { [fixedDate] in fixedDate })
        let first = try inbox.importFiles([try file("a.png")])
        let second = try inbox.importFiles([try file("b.png")])
        #expect(first[0].deletingLastPathComponent() != second[0].deletingLastPathComponent())
    }

    @Test("two files with one name are both kept")
    func sameName() throws {
        let other = source.appendingPathComponent("More", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let twin = other.appendingPathComponent("photo.jpg")
        try Data("twin".utf8).write(to: twin)
        let copies = try DocumentInbox(root: root).importFiles([try file("photo.jpg"), twin])
        #expect(copies.map(\.lastPathComponent) == ["photo.jpg", "photo 2.jpg"])
    }

    @Test("nothing to import is reported")
    func empty() {
        #expect(throws: JobError.nothingFound) { try DocumentInbox(root: root).importFiles([]) }
    }

    @Test("a missing file fails the import and leaves no folder behind")
    func missing() throws {
        let inbox = DocumentInbox(root: root)
        #expect(throws: JobError.sourceMissing) {
            try inbox.importFiles([try file("here.txt"), source.appendingPathComponent("gone.txt")])
        }
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        #expect(leftovers.isEmpty)
    }
}
