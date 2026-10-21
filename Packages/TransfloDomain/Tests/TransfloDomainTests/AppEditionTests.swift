import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("App edition")
struct AppEditionTests {
    @Test("the direct edition offers everything; the App Store edition drops what the sandbox forbids")
    func capabilities() {
        #expect(AppEdition.direct.supportsFinderSelection && AppEdition.direct.supportsIWork)
        #expect(!AppEdition.direct.installsUpdatesFromStore && !AppEdition.direct.needsFolderAccess)
        #expect(AppEdition.direct.unavailableActions.isEmpty)
        #expect(!AppEdition.appStore.supportsFinderSelection && !AppEdition.appStore.supportsIWork)
        #expect(AppEdition.appStore.installsUpdatesFromStore && AppEdition.appStore.needsFolderAccess)
        #expect(AppEdition.appStore.unavailableActions == [.terminal])
    }

    @Test("Settings › Wheel lists only the actions an edition offers")
    func choicesFollowEdition() {
        let actions = ActionKind.allCases.filter { !AppEdition.appStore.unavailableActions.contains($0) }
        let sut = ListWheelChoicesUseCase(catalog: CatalogFixtures.catalog, tools: ToolFixtures.catalog,
                                          actions: actions)
        let listed = sut.execute(wheel: .actions).first?.options ?? []
        #expect(!listed.contains(WheelOption(.action(.terminal))))
        #expect(listed.count == ActionKind.allCases.count - 1)
    }
}

@Suite("Granted folders")
struct GrantedFoldersTests {
    private let home = URL(fileURLWithPath: "/Users/me")

    @Test("access to a folder covers everything inside it, but not its siblings or parents")
    func coverage() {
        let sut = GrantedFolders([home.appendingPathComponent("Desktop")])
        #expect(sut.covers(home.appendingPathComponent("Desktop")))
        #expect(sut.covers(home.appendingPathComponent("Desktop/Photos/2026")))
        #expect(!sut.covers(home))
        #expect(!sut.covers(home.appendingPathComponent("Desktop Archive")))
        #expect(!sut.covers(home.appendingPathComponent("Documents")))
    }

    @Test("missing folders are listed once each, ignoring covered ones and path spelling")
    func missing() {
        let sut = GrantedFolders([home.appendingPathComponent("Desktop")])
        let items = [
            home.appendingPathComponent("Desktop/a.png"),
            home.appendingPathComponent("Documents/b.png"),
            home.appendingPathComponent("Documents/./c.png"),
            URL(fileURLWithPath: "/Volumes/Card/d.png")
        ]
        #expect(sut.missing(for: items).map(\.path) == [home.appendingPathComponent("Documents").path, "/Volumes/Card"])
    }

    @Test("adding a folder already covered keeps the list short")
    func addCovered() {
        var sut = GrantedFolders([home])
        sut.add(home.appendingPathComponent("Desktop"))
        #expect(sut.folders.map(\.path) == [home.path])
        #expect(GrantedFolders.canonical(home) == GrantedFolders.canonical(URL(fileURLWithPath: "/Users/me/")))
    }
}
