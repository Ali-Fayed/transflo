import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Smart Rename editor")
struct SmartRenameEditorTests {
    private let items = [URL(fileURLWithPath: "/tmp/IMG_1.jpg"), URL(fileURLWithPath: "/tmp/IMG_2.png")]

    private func suggester(_ writer: StubTextWriter,
                           _ understanding: StubImageUnderstanding = StubImageUnderstanding(labels: ["dog"]))
        -> SuggestFileNamesUseCase {
        SuggestFileNamesUseCase(understanding: understanding, writer: writer, created: { _ in nil })
    }

    @Test("loads one suggestion per file and applies the edited names")
    func suggestsAndEdits() async {
        let sut = SmartRenameEditorViewModel(items: items,
                                             suggester: suggester(StubTextWriter(names: ["Golden Dog", "Receipt"])))
        await sut.load()
        #expect(sut.names == ["golden-dog", "receipt"] && sut.error == nil && !sut.isSuggesting)
        #expect(sut.preview(at: 1) == "receipt.png")
        sut.names[1] = "Coffee Receipt!"
        #expect(sut.settings == .renameTo(["golden-dog", "coffee-receipt"]))
        sut.names[0] = "IMG_1"
        #expect(sut.settings == .renameTo(["IMG_1", "coffee-receipt"]))
    }

    @Test("an emptied name blocks renaming")
    func emptyNameBlocks() async {
        let sut = SmartRenameEditorViewModel(items: items, suggester: suggester(StubTextWriter(names: ["a", "b"])))
        await sut.load()
        sut.names[0] = "  ...  "
        #expect(sut.settings == nil)
        #expect(sut.preview(at: 5).isEmpty)
    }

    @Test("without Apple Intelligence it keeps the current names and explains")
    func unavailable() async {
        let sut = SmartRenameEditorViewModel(items: items, suggester: suggester(StubTextWriter(isAvailable: false)))
        await sut.load()
        #expect(sut.names == ["IMG_1", "IMG_2"])
        #expect(sut.error == JobPresentation.message(for: .unsupported))
        #expect(sut.settings == nil)
    }

    @Test("a failed suggestion shows the error")
    func failure() async {
        let sut = SmartRenameEditorViewModel(items: items, suggester: suggester(StubTextWriter(error: .failed)))
        await sut.load()
        #expect(sut.error == .errorFailed && sut.settings == nil)
        let missing = SmartRenameEditorViewModel(items: items, suggester: nil)
        await missing.load()
        #expect(missing.error == JobPresentation.message(for: .unsupported))
    }
}
