@testable import Transflo
import TransfloDomain

/// Records every appearance applied.
final class SpyAppearanceApplier: AppearanceApplying {
    private(set) var applied: [AppearanceMode] = []

    func apply(_ appearance: AppearanceMode) {
        applied.append(appearance)
    }
}
