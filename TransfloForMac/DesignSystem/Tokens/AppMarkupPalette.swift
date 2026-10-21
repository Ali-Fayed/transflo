import SwiftUI

/// Colors the user puts into their files (marks, backgrounds, redaction). They are file content,
/// not interface colors, so they keep the same `#RRGGBB` value in every appearance.
enum AppMarkupPalette {
    /// One choosable color.
    struct Swatch: Hashable, Identifiable {
        let hex: String
        let label: L10nKey
        var id: String { hex }
    }

    static let swatches: [Swatch] = [
        Swatch(hex: "#E5484D", label: .colorRed),
        Swatch(hex: "#FFC53D", label: .colorYellow),
        Swatch(hex: "#30A46C", label: .colorGreen),
        Swatch(hex: "#12A594", label: .colorTeal),
        Swatch(hex: "#3E63DD", label: .colorBlue),
        Swatch(hex: "#111111", label: .colorBlack),
        Swatch(hex: "#FFFFFF", label: .colorWhite)
    ]
    static let defaultInk = "#E5484D"
    static let defaultBackground = "#FFFFFF"
    /// What redaction burns in.
    static let redaction = "#000000"

    /// `#RRGGBB` as a color; anything unreadable is black.
    static func color(_ hex: String) -> Color {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return Color(.sRGB, red: channel(value >> 16), green: channel(value >> 8), blue: channel(value))
    }

    private static func channel(_ value: UInt32) -> Double {
        Double(value & 0xFF) / 255
    }
}
