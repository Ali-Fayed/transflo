import AppKit
import Foundation
import Testing
import TransfloDomain
@testable import TransfloSystem

@Suite("Action adapters")
struct ActionAdapterTests {
    @Test("copied files land on the pasteboard as file URLs")
    func copiesFiles() async throws {
        let name = NSPasteboard.Name("transflo-tests-\(UUID().uuidString)")
        let files = [URL(fileURLWithPath: "/tmp/a.png"), URL(fileURLWithPath: "/tmp/b c.pdf")]
        try await PasteboardFileCopier(name: name).copyFiles(files)
        let read = await MainActor.run {
            let pasteboard = NSPasteboard(name: name)
            defer { pasteboard.releaseGlobally() }
            return pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
        }
        #expect(read.map(\.path) == files.map(\.path))
    }

    @Test("Terminal is always installed and listed first")
    func installedTerminals() {
        #expect(WorkspaceTerminalOpener().installedApps().first == .terminal)
    }
}
