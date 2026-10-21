import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

struct ToolNameStyleTests {
    @Test func supportsBothStylesAndCollisionNumbering() throws {
        let folder = URL(fileURLWithPath: "/tmp")
        let source = folder.appendingPathComponent("photo.jpg")
        let preferences = InMemoryToolPreferences()
        let naming = ToolOutputNaming(naming: NameOutputFileUseCase(checker: FakeFileExistenceChecker(existing: [
            folder.appendingPathComponent("photo Crop.jpg")
        ])), suffixes: StubToolSuffixes(), style: preferences)
        #expect(try naming.destination(for: source, tool: .crop).lastPathComponent == "photo (crop).jpg")
        preferences.saveNameStyle(.word)
        #expect(try naming.destination(for: source, tool: .crop).lastPathComponent == "photo Crop 2.jpg")
        let bare = folder.appendingPathComponent("file")
        #expect(try naming.destination(for: bare, tool: .crop).lastPathComponent == "file Crop")
    }

    @Test func arabicSuffixIsPreserved() throws {
        let suffix = ArabicToolSuffixes()
        let naming = ToolOutputNaming(naming: NameOutputFileUseCase(checker: FakeFileExistenceChecker(existing: [])),
                                       suffixes: suffix, style: InMemoryToolPreferences(style: .word))
        #expect(try naming.destination(for: URL(fileURLWithPath: "/tmp/صورة.jpg"), tool: .crop)
            .lastPathComponent == "صورة مقصوصة.jpg")
    }

    private struct ArabicToolSuffixes: ToolSuffixProviding {
        func suffix(for tool: ToolKind) -> String { "مقصوصة" }
    }
}
