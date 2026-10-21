import Foundation
import Observation
import TransfloDomain

@Observable
final class UpdateViewModel {
    private(set) var message: L10nKey = .updateChecking
    private(set) var availableVersion: String?
    private(set) var isChecking = false
    let currentVersion: String
    let text: UpdateChannelText
    @ObservationIgnored private let checker: any AppUpdateChecking

    init(checker: any AppUpdateChecking, text: UpdateChannelText, currentVersion: String) {
        self.checker = checker
        self.text = text
        self.currentVersion = currentVersion
    }

    /// The release page or the App Store listing.
    var downloadURL: URL { checker.downloadURL }

    func check() async {
        guard !isChecking else { return }
        isChecking = true
        availableVersion = nil
        message = .updateChecking
        defer { isChecking = false }
        do {
            switch try await checker.check(currentVersion: currentVersion) {
            case .available(let version):
                availableVersion = version
                message = .updateAvailable
            case .upToDate: message = .updateCurrent
            case .noPublishedRelease: message = text.noRelease
            }
        } catch {
            message = text.failed
        }
    }
}
