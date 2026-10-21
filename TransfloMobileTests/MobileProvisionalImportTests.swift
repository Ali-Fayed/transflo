import Foundation
import Testing
import TransfloData
import TransfloDomain
@testable import TransfloMobile

@Suite("Provisional imports")
struct MobileProvisionalImportTests {
    @Test("backing out of a Home import removes its copy; running something keeps it")
    func discardAndCommit() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try file(in: root, named: "photo.png")
        let documents = root.appendingPathComponent("Documents")
        let provisional = MobileProvisionalImport()
        let home = MobileHomeViewModel(importer: DocumentInbox(root: documents), wheel: SpyWheelOpener(),
                                       provisional: provisional)
        // When a file is picked and the wheel is closed without running anything
        await home.receive([source])
        #expect(provisional.isPending && imports(in: documents).count == 1)
        home.wheelFlowEnded()
        #expect(imports(in: documents).isEmpty && FileManager.default.fileExists(atPath: source.path))
        // When a job is scheduled for the next import
        await home.receive([source])
        let scheduler = ImportCommittingScheduler(base: SpyJobScheduler(), imports: provisional)
        scheduler.schedule(WheelOption(.tool(.compress)), items: [], near: WheelPoint(x: 0, y: 0))
        home.wheelFlowEnded()
        #expect(imports(in: documents).count == 1 && !provisional.isPending)
    }

    @Test("an import with no options for it is removed at once")
    func noOptions() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let documents = root.appendingPathComponent("Documents")
        let home = MobileHomeViewModel(importer: DocumentInbox(root: documents),
                                       wheel: SpyWheelOpener(hasOptions: false),
                                       provisional: MobileProvisionalImport())
        await home.receive([try file(in: root, named: "notes.png")])
        #expect(home.state.message == .mobileNoOptions && imports(in: documents).isEmpty)
    }

    @Test("files from different folders, or no import at all, are never removed")
    func neverRemovesOthers() {
        var removed: [URL] = []
        let provisional = MobileProvisionalImport { removed.append($0) }
        provisional.discard()
        provisional.begin([URL(fileURLWithPath: "/a/one.png"), URL(fileURLWithPath: "/b/two.png")])
        provisional.discard()
        #expect(removed.isEmpty && !provisional.isPending)
    }

    private func imports(in documents: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
    }

    private func workspace() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func file(in root: URL, named name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
        return url
    }
}
