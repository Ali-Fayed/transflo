import Foundation
import Testing
@testable import TransfloSystem

@MainActor
@Suite("Folder watcher", .serialized)
struct FolderWatcherTests {
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("transflo-watch-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test("new visible files are reported once written; existing and hidden files never are")
    func reportsNewFiles() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("old".utf8).write(to: folder.appendingPathComponent("existing.png"))
        var reported: [String] = []
        let sut = FolderWatcher(folder: folder, settle: .milliseconds(150)) { urls in
            reported += urls.map(\.lastPathComponent)
        }
        #expect(sut.start())
        try Data("new".utf8).write(to: folder.appendingPathComponent("shot.png"))
        try Data("x".utf8).write(to: folder.appendingPathComponent(".transflo-staging"))
        for _ in 0..<60 where reported.isEmpty { try await Task.sleep(for: .milliseconds(50)) }
        try await Task.sleep(for: .milliseconds(400))
        sut.stop()
        #expect(reported == ["shot.png"])
    }

    @Test("a missing folder can't be watched")
    func missingFolder() {
        let sut = FolderWatcher(folder: URL(fileURLWithPath: "/nonexistent/\(UUID())")) { _ in }
        #expect(!sut.start())
    }

    @Test("a different file replacing an existing name is reported")
    func reportsReplacements() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("same.png")
        try Data([1]).write(to: url)
        var reported: [URL] = []
        let watcher = FolderWatcher(folder: folder, settle: .milliseconds(100)) { reported += $0 }
        #expect(watcher.start())
        defer { watcher.stop() }
        try Data([2]).write(to: url, options: .atomic)
        for _ in 0..<60 where reported.isEmpty { try await Task.sleep(for: .milliseconds(50)) }
        #expect(reported == [url])
    }
}
