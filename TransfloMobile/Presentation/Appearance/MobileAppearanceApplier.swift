import Observation
import SwiftUI
import TransfloDomain

/// Applies the appearance as the root view's preferred color scheme (`nil` follows the system).
@Observable
final class MobileAppearanceApplier: AppearanceApplying {
    private(set) var colorScheme: ColorScheme?

    init(_ appearance: AppearanceMode) {
        colorScheme = Self.scheme(for: appearance)
    }

    func apply(_ appearance: AppearanceMode) {
        colorScheme = Self.scheme(for: appearance)
    }

    static func scheme(for appearance: AppearanceMode) -> ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
