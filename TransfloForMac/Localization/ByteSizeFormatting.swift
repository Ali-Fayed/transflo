import Foundation

/// Strategy for byte-count presentation in the language chosen inside Transflo.
protocol ByteSizeFormatting {
    func string(bytes: Int64, locale: Locale) -> String
}
