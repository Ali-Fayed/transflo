import Foundation
import Testing
import TransfloData
import TransfloDomain

@Suite("Mobile workspace and history storage")
struct WorkspaceAndHistoryTests {
    private let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("workspace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @discardableResult
    private func file(_ path: String, _ contents: String = "x") throws -> URL {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test("imports list with their files and results; iOS's Inbox, hidden and empty folders don't")
    func lists() throws {
        try file("2026-10-20 at 10.00.00/photo.heic", "12345")
        try file("2026-10-20 at 10.00.00/photo (compress).jpg")
        try file("Inbox/mail.pdf")
        try file("2026-10-20 at 11.00.00/.hidden")
        let folders = try DocumentWorkspace(root: root).folders()
        #expect(folders.count == 1)
        #expect(Set(folders[0].files.map(\.name)) == ["photo.heic", "photo (compress).jpg"])
        #expect(folders[0].files.first { $0.name == "photo.heic" }?.bytes == 5)
    }

    @Test("a missing workspace is simply empty")
    func missingRoot() throws {
        #expect(try DocumentWorkspace(root: root.appendingPathComponent("none")).folders().isEmpty)
    }

    @Test("deleting the last file removes its import folder; nothing outside the workspace is touched")
    func delete() throws {
        let only = try file("2026-10-20 at 10.00.00/photo.heic")
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("keep-\(UUID().uuidString).txt")
        try Data("keep".utf8).write(to: outside)
        let workspace = DocumentWorkspace(root: root)
        try workspace.delete([only])
        #expect(try workspace.folders().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: only.deletingLastPathComponent().path))
        #expect(throws: JobError.destinationUnavailable) { try workspace.delete([outside]) }
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test("history round-trips through its file, newest first, and an unreadable file reads as empty")
    func history() throws {
        let store = FileJobHistoryRepository(file: root.appendingPathComponent("Support/history.json"))
        let record = RecordJobHistoryUseCase(repository: store, limit: 2)
        let entries = (0..<3).map { index in
            JobHistoryEntry(id: UUID(), finishedAt: Date(timeIntervalSince1970: Double(index)),
                            title: .init(key: "tool.compress"), files: .init(key: nil, verbatim: "photo.heic"),
                            outputs: ["a/photo (compress).jpg"], failed: index == 1)
        }
        entries.forEach(record.execute)
        #expect(store.load().map(\.id) == [entries[2].id, entries[1].id])
        record.execute(entries[1])
        #expect(store.load().map(\.id) == [entries[1].id, entries[2].id])
        record.clear()
        #expect(store.load().isEmpty)
        try Data("not json".utf8).write(to: root.appendingPathComponent("Support/history.json"))
        #expect(store.load().isEmpty)
    }
}
