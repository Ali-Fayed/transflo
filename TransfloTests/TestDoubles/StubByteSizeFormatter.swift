import Foundation
@testable import Transflo

/// Deterministic byte labels for wheel-state tests.
struct StubByteSizeFormatter: ByteSizeFormatting {
    func string(bytes: Int64, locale: Locale) -> String { "size-\(bytes)" }
}
