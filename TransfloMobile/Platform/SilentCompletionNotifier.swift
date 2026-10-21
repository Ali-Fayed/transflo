import Foundation
import TransfloDomain

/// Jobs on iPhone and iPad run while Transflo is on screen and report in the app itself, so a
/// finished job posts no system notification.
nonisolated struct SilentCompletionNotifier: CompletionNotifying {
    func notify(title: String, body: String, revealing urls: [URL]) {}
}
