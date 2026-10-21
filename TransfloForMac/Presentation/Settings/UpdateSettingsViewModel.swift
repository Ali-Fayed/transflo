import Observation
import TransfloDomain

/// Settings › General › Updates: the automatic-check switch.
@Observable
final class UpdateSettingsViewModel {
    private(set) var checksAutomatically: Bool
    @ObservationIgnored private let repository: any UpdatePreferencesRepository

    init(repository: any UpdatePreferencesRepository) {
        self.repository = repository
        checksAutomatically = repository.loadChecksAutomatically()
    }

    func setChecksAutomatically(_ enabled: Bool) {
        guard enabled != checksAutomatically else { return }
        checksAutomatically = enabled
        repository.saveChecksAutomatically(enabled)
    }
}
