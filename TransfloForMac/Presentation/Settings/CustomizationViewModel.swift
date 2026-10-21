import Observation
import TransfloDomain

/// Saves visual changes and applies them immediately to all Transflo windows.
@Observable
final class CustomizationViewModel {
    private(set) var preferences: InterfaceCustomization
    @ObservationIgnored private let repository: any SettingsRepository
    @ObservationIgnored private let style: InterfaceStyle

    init(repository: any SettingsRepository, style: InterfaceStyle = .shared) {
        self.repository = repository
        self.style = style
        self.preferences = repository.loadCustomization() ?? .standard
    }

    func update(_ edit: (inout InterfaceCustomization) -> Void) {
        var next = preferences
        edit(&next)
        next = next.validated
        guard next != preferences else { return }
        repository.saveCustomization(next)
        preferences = next
        style.apply(next)
    }

    func reset() {
        update { $0 = .standard }
    }
}
