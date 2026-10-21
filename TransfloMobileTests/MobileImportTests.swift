import Foundation
import Testing
@testable import TransfloMobile

@Suite("Mobile import staging")
struct MobileImportTests {
    @Test("staging contains provider names and cleanup preserves the original")
    func stagingAndCleanup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("photo.jpg")
        let contents = Data("sample image".utf8)
        try contents.write(to: source)
        let staged = try #require(ItemProviderFileLoader.stage(source, named: "../../outside"))
        defer { ItemProviderFileLoader.discard([staged]) }
        #expect(staged.lastPathComponent == "outside.jpg")
        #expect(try Data(contentsOf: staged) == contents)
        ItemProviderFileLoader.discard([staged, source])
        #expect(!FileManager.default.fileExists(atPath: staged.deletingLastPathComponent().path))
        #expect(try Data(contentsOf: source) == contents)
    }
}
