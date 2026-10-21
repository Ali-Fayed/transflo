import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Actions")
struct ActionTests {
    private let file = URL(fileURLWithPath: "/Users/example/Desktop/photo.heic")
    private let folder = URL(fileURLWithPath: "/Users/example/Projects/", isDirectory: true)
    private let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

    private func runner(_ performers: [ActionKind: any FileActionPerforming], existing: [URL]? = nil)
        -> ActionJobRunner {
        ActionJobRunner(performers: performers, checker: FakeFileExistenceChecker(existing: existing ?? [file, folder]))
    }

    @Test("the runner sends each action to its performer and reports completion")
    func routes() async throws {
        let copier = SpyFileCopier()
        let sut = runner([.copy: CopyFilesAction(copier: copier)])
        let progress = ProgressRecorder()
        let outputs = try await sut.run(WheelOption(.action(.copy)), on: [file, folder], progress: progress.record)
        #expect(outputs.isEmpty)
        #expect(copier.received == [[file, folder]])
        #expect(progress.values == [1])
    }

    @Test("missing sources, empty selections and unregistered actions fail before acting")
    func guards() async {
        let copier = SpyFileCopier()
        let sut = runner([.copy: CopyFilesAction(copier: copier)], existing: [folder])
        await #expect(throws: JobError.sourceMissing) {
            try await sut.run(WheelOption(.action(.copy)), on: [file]) { _ in }
        }
        await #expect(throws: JobError.sourceMissing) {
            try await sut.run(WheelOption(.action(.copy)), on: []) { _ in }
        }
        await #expect(throws: JobError.unsupported) {
            try await sut.run(WheelOption(.action(.airDrop)), on: [folder]) { _ in }
        }
        await #expect(throws: JobError.unsupported) {
            try await sut.run(WheelOption(.tool(.crop)), on: [folder]) { _ in }
        }
        #expect(copier.received.isEmpty)
    }

    @Test("copy and AirDrop pass their failures through")
    func failures() async {
        let failing = SpyFileCopier(failingWith: .unsupported)
        await #expect(throws: JobError.unsupported) {
            try await AirDropAction(sharer: failing).perform(on: [file], settings: nil)
        }
        await #expect(throws: JobError.failed) {
            try await CopyFilesAction(copier: SpyFileCopier(failingWith: .failed)).perform(on: [file], settings: nil)
        }
    }

    @Test("copy path writes one path per line; ⌥ abbreviates the home folder")
    func copyPath() async throws {
        let outside = URL(fileURLWithPath: "/Volumes/Disk/a b.txt")
        let copier = SpyTextCopier()
        _ = try await CopyPathAction(copier: copier, modifiers: StubModifierState(), home: home)
            .perform(on: [file, outside], settings: nil)
        _ = try await CopyPathAction(copier: copier, modifiers: StubModifierState(optionPressed: true), home: home)
            .perform(on: [file, outside, home], settings: nil)
        #expect(copier.copied == [
            "/Users/example/Desktop/photo.heic\n/Volumes/Disk/a b.txt",
            "~/Desktop/photo.heic\n/Volumes/Disk/a b.txt\n~"
        ])
    }

    @Test("a home-like prefix that is not the home folder stays absolute")
    func homePrefix() {
        let sibling = URL(fileURLWithPath: "/Users/alice/notes.txt")
        #expect(CopyPathFormatter.text(for: [sibling], home: home, abbreviatingHome: true) == "/Users/alice/notes.txt")
        #expect(CopyPathFormatter.text(for: [sibling], home: nil, abbreviatingHome: true) == "/Users/alice/notes.txt")
    }

    @Test("terminal opens folders as themselves and files as their folder, once each")
    func terminalFolders() {
        let other = URL(fileURLWithPath: "/Users/example/Desktop/notes.txt")
        let folders = TerminalFolders.folders(for: [file, folder, other], isDirectory: \.hasDirectoryPath)
        #expect(folders.map(\.path) == ["/Users/example/Desktop", "/Users/example/Projects"])
    }

    @Test("terminal uses the preferred app when installed, else the first installed one")
    func terminalChoice() async throws {
        let opener = SpyTerminalOpener(installed: [.terminal, .ghostty])
        let preferGhostty = TerminalAction(opener: opener, directories: StubDirectoryChecker()) { .ghostty }
        let preferWarp = TerminalAction(opener: opener, directories: StubDirectoryChecker()) { .warp }
        _ = try await preferGhostty.perform(on: [folder], settings: nil)
        _ = try await preferWarp.perform(on: [file], settings: nil)
        #expect(opener.received.map(\.app) == [.ghostty, .terminal])
        #expect(opener.received.last?.folders.map(\.path) == ["/Users/example/Desktop"])
    }

    @Test("terminal without any installed app is unsupported")
    func noTerminal() async {
        let sut = TerminalAction(opener: SpyTerminalOpener(installed: []), directories: StubDirectoryChecker()) {
            .terminal
        }
        await #expect(throws: JobError.unsupported) { try await sut.perform(on: [folder], settings: nil) }
    }

    @Test("move needs a destination, returns the new places and remembers the folder")
    func move() async throws {
        let mover = SpyFileMover()
        let recents = InMemoryRecentFolders([home])
        let sut = MoveAction(mover: mover, recents: recents)
        await #expect(throws: JobError.unsupported) { try await sut.perform(on: [file], settings: nil) }
        let moved = try await sut.perform(on: [file], settings: .destination(folder))
        #expect(moved.map(\.path) == ["/Users/example/Projects/photo.heic"])
        #expect(recents.load().map(\.path) == ["/Users/example/Projects", "/Users/example"])
    }

    @Test("a failed move leaves the recent folders alone")
    func failedMove() async {
        let recents = InMemoryRecentFolders([home])
        let sut = MoveAction(mover: SpyFileMover(failingWith: .destinationUnavailable), recents: recents)
        await #expect(throws: JobError.destinationUnavailable) {
            try await sut.perform(on: [file], settings: .destination(folder))
        }
        #expect(recents.load() == [home])
    }

    @Test("recent folders keep the newest five without duplicates")
    func recentFolders() {
        let folders = (1...5).map { URL(fileURLWithPath: "/f\($0)") }
        let again = RecentFolders.adding(URL(fileURLWithPath: "/f3/"), to: folders)
        #expect(again.map(\.path) == ["/f3", "/f1", "/f2", "/f4", "/f5"])
        let fresh = RecentFolders.adding(URL(fileURLWithPath: "/new"), to: folders)
        #expect(fresh.count == RecentFolders.limit && fresh.first?.path == "/new" && fresh.last?.path == "/f4")
    }

    @Test("float puts the files on the shelf and produces nothing")
    func float() async throws {
        let shelf = SpyShelf()
        #expect(try await FloatAction(shelf: shelf).perform(on: [file, folder], settings: nil).isEmpty)
        #expect(shelf.received == [[file, folder]])
    }

    @Test("terminal apps carry their bundle identifiers")
    func bundleIdentifiers() {
        #expect(TerminalApp.allCases.map(\.bundleIdentifier) == [
            "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable"
        ])
    }
}
