import Testing
@testable import TransfloMobile

@Suite("Mobile navigation")
struct MobileCoordinatorTests {
    @Test("Settings selects its tab, and returning to root selects Home")
    func settings() {
        // Given a coordinator at the root
        let sut = MobileCoordinator()
        // When Settings opens, then the app returns home
        sut.showSettings()
        #expect(sut.selectedTab == .settings)
        sut.popToRoot()
        // Then nothing is left on the stack
        #expect(sut.selectedTab == .home)
    }

    @Test("the Home Recipes shortcut opens its actual settings destination")
    func recipesShortcut() {
        let coordinator = MobileCoordinator()
        coordinator.showRecipes()
        #expect(coordinator.selectedTab == .settings)
        #expect(coordinator.settingsPath == [.recipes])
        coordinator.showFiles()
        coordinator.showRecipes()
        #expect(coordinator.settingsPath == [.recipes])
    }
}
