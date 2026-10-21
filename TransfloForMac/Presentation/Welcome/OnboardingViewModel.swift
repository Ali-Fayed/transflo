import Observation
import TransfloDomain

/// Five short pages; completion and login-item state come from injected repositories and use cases.
@Observable
final class OnboardingViewModel {
    static let pageCount = 5
    private(set) var page = 0
    /// Counts openings of Getting Started, so each one replays the page entrance.
    private(set) var presentation = 0
    private(set) var movingForward = true
    private(set) var launchAtLogin: Bool
    private(set) var errorState: SettingsErrorState?
    @ObservationIgnored private let repository: any SettingsRepository
    @ObservationIgnored private let keys: any InputPreferencesRepository
    @ObservationIgnored private let getLogin: GetLaunchAtLoginStatusUseCase
    @ObservationIgnored private let setLogin: SetLaunchAtLoginUseCase

    init(
        repository: any SettingsRepository,
        keys: any InputPreferencesRepository,
        getLogin: GetLaunchAtLoginStatusUseCase,
        setLogin: SetLaunchAtLoginUseCase
    ) {
        self.repository = repository
        self.keys = keys
        self.getLogin = getLogin
        self.setLogin = setLogin
        self.launchAtLogin = getLogin.execute()
    }

    var needsOnboarding: Bool { !repository.loadHasCompletedOnboarding() }
    var canGoBack: Bool { page > 0 }
    var isLastPage: Bool { page == Self.pageCount - 1 }

    func key(for wheel: WheelKind) -> ModifierKey? { keys.load().wheelKeys.key(for: wheel) }

    func start(at page: Int = 0) {
        self.page = min(max(0, page), Self.pageCount - 1)
        presentation += 1
        movingForward = true
        launchAtLogin = getLogin.execute()
        errorState = nil
    }

    func next() {
        guard !isLastPage else { return }
        movingForward = true
        page += 1
    }

    func back() {
        guard canGoBack else { return }
        movingForward = false
        page -= 1
    }

    @discardableResult
    func finish() -> Bool {
        guard isLastPage else { return false }
        repository.saveHasCompletedOnboarding(true)
        return true
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try setLogin.execute(enabled)
            errorState = nil
        } catch {
            errorState = switch error {
            case .requiresApproval: .launchAtLoginRequiresApproval
            case .failed: .launchAtLoginFailed
            }
        }
        launchAtLogin = getLogin.execute()
    }
}
