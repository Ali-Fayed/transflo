import AppKit
import TransfloDomain

/// Applies the appearance through `NSApp.appearance`, which covers windows, menus and panels.
final class NSAppAppearanceApplier: AppearanceApplying {
    func apply(_ appearance: AppearanceMode) {
        NSApp.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
