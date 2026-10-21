import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("PreviewWheelOptionsProvider")
struct PreviewWheelOptionsProviderTests {
    private let items = [URL(fileURLWithPath: "/tmp/a.png")]

    @Test("convert is left to the catalog")
    func convert() {
        #expect(PreviewWheelOptionsProvider().options(for: .convert, items: items).isEmpty)
    }

    @Test("tools and actions list every case")
    func toolsAndActions() {
        let sut = PreviewWheelOptionsProvider()
        #expect(sut.options(for: .tools, items: items).count == ToolKind.allCases.count)
        #expect(sut.options(for: .actions, items: items).map(\.kind) == ActionKind.allCases.map { .action($0) })
    }

    @Test("the existence checker reflects the file system")
    func existenceChecker() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let file = try folder.file("here.txt")
        #expect(FileManagerExistenceChecker().fileExists(at: file))
        #expect(FileManagerExistenceChecker().fileExists(at: folder.url.appendingPathComponent("nope")) == false)
    }
}

@Suite("Actions per edition")
struct EditionActionsTests {
    @Test("actions an edition can't perform are left off the Actions wheel")
    func excludesUnavailable() {
        let sut = PreviewWheelOptionsProvider(unavailableActions: [.terminal])
        let actions = sut.options(for: .actions, items: [URL(fileURLWithPath: "/tmp/a.png")])
        #expect(!actions.contains(WheelOption(.action(.terminal))))
        #expect(actions.count == ActionKind.allCases.count - 1)
        #expect(PreviewWheelOptionsProvider().options(for: .actions, items: []).count == ActionKind.allCases.count)
    }
}
