import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Move destination picker")
struct MoveDestinationPickerTests {
    @Test("only Move needs a choice, and only folders that still exist are offered")
    func destinations() {
        let kept = URL(fileURLWithPath: "/Users/example/Projects/", isDirectory: true)
        let gone = URL(fileURLWithPath: "/Volumes/Unplugged")
        let sut = MoveDestinationPicker(
            recents: InMemoryRecentFolders([gone, kept]),
            directories: StubDirectoryChecker(),
            localizer: Localizer(language: .english)
        )
        #expect(ActionKind.allCases.filter(sut.needsPreparation) == [.move])
        #expect(sut.destinations() == [kept])
    }
}
