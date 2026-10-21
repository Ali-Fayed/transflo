import Observation
import TransfloDomain

/// First-run state is persisted only by an explicit Skip or Finish. Replays keep saved preferences.
@Observable
final class MobileOnboardingViewModel {
    static let pageCount = 4
    private(set) var page = 0
    private(set) var isPresented: Bool
    @ObservationIgnored private let repository: any SettingsRepository

    init(repository: any SettingsRepository) {
        self.repository = repository
        isPresented = !repository.loadHasCompletedOnboarding()
    }

    var isLastPage: Bool { page == Self.pageCount - 1 }

    func next() { if !isLastPage { page += 1 } }
    func back() { if page > 0 { page -= 1 } }

    func replay() {
        page = 0
        isPresented = true
    }

    func finish() {
        guard isLastPage else { return }
        skip()
    }

    func skip() {
        repository.saveHasCompletedOnboarding(true)
        isPresented = false
    }
}
