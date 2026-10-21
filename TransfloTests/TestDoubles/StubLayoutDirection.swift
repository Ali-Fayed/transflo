@testable import Transflo

/// A fixed reading direction.
final class StubLayoutDirection: LayoutDirectionProviding {
    var isRightToLeft: Bool

    init(isRightToLeft: Bool = false) {
        self.isRightToLeft = isRightToLeft
    }
}
