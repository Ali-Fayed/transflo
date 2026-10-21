import Foundation
import TransfloDomain

/// Builds the update check for one edition: the Check for Updates window and the automatic daily check.
struct UpdateFactory {
    let checker: any AppUpdateChecking
    let text: UpdateChannelText
    let preferences: any UpdatePreferencesRepository
    let currentVersion: String

    func makeViewModel() -> UpdateViewModel {
        UpdateViewModel(checker: checker, text: text, currentVersion: currentVersion)
    }

    func makeScheduler(notifier: any UpdateNotifying, localizer: Localizer) -> AutomaticUpdateScheduler {
        AutomaticUpdateScheduler(
            check: AutomaticUpdateCheckUseCase(checker: checker, preferences: preferences,
                                               currentVersion: currentVersion),
            notifier: notifier,
            localizer: localizer,
            text: text,
            downloadURL: checker.downloadURL
        )
    }
}
