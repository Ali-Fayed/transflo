@testable import Transflo
import TransfloDomain

/// Records hints.
final class SpyHints: HintPresenting {
    private(set) var shown: [L10nKey] = []

    func showHint(_ message: L10nKey, near point: WheelPoint) {
        shown.append(message)
    }
}
