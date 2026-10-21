import SwiftUI
import TransfloDomain

/// Shared gradient-content tokens with localized UI names; export reads the same domain presets.
enum AppBackgroundPresets {
    static let all = BackgroundPreset.allCases

    static func gradient(_ preset: BackgroundPreset) -> LinearGradient {
        let radians = preset.angleDegrees * .pi / 180
        let deltaX = cos(radians) / 2
        let deltaY = sin(radians) / 2
        return LinearGradient(colors: [AppMarkupPalette.color(preset.colors.start),
                                        AppMarkupPalette.color(preset.colors.end)],
                              startPoint: UnitPoint(x: 0.5 - deltaX, y: 0.5 + deltaY),
                              endPoint: UnitPoint(x: 0.5 + deltaX, y: 0.5 - deltaY))
    }

    static func label(_ preset: BackgroundPreset) -> L10nKey {
        switch preset {
        case .lagoon: .backgroundLagoon
        case .moss: .backgroundMoss
        case .linen: .backgroundLinen
        case .glacier: .backgroundGlacier
        case .slate: .backgroundSlate
        case .amber: .backgroundAmber
        case .ink: .backgroundInk
        case .seaGlass: .backgroundSeaGlass
        }
    }
}
