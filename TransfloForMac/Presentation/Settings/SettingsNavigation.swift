import Observation

/// Shared navigation lets menu shortcuts select a tab in an existing Settings window.
@Observable
final class SettingsNavigation {
    enum Tab: Hashable { case general, wheel, recipes, compatibility, about }
    var selectedTab: Tab = .general
}
