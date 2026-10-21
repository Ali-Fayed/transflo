import SwiftUI

/// Semantic colors. Values live in the asset catalog with light and dark variants.
enum AppColors {
    /// The welcome canvas gradient. It follows the accent chosen in Customization.
    static var onboardingStart: Color { onboardingGradient(accentHex: chosenAccentHex).start }
    static var onboardingEnd: Color { onboardingGradient(accentHex: chosenAccentHex).end }
    private static var chosenAccentHex: String? { InterfaceStyle.shared.preferences.accentHex }
    static let background = Color(.background)
    static let surface = Color(.surface)
    /// A page's paper in previews of exported documents (white, or dark in Dark Mode).
    static var paper: Color { AppPlatform.paper }
    static let divider = Color(.divider)
    static let textPrimary = Color(.textPrimary)
    static let textSecondary = Color(.textSecondary)
    static var accent: Color {
        guard let hex = InterfaceStyle.shared.preferences.accentHex else { return Color(.accent) }
        return color(hex: hex)
    }
    static var accentContrast: Color {
        guard let hex = InterfaceStyle.shared.preferences.accentHex, let rgb = UInt32(hex, radix: 16)
        else { return Color(.accentContrast) }
        let components = [Double((rgb >> 16) & 255), Double((rgb >> 8) & 255), Double(rgb & 255)].map { value in
            let component = value / 255
            return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        let luminance = components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
        return luminance > 0.179 ? .black : .white
    }

    static func color(hex: String) -> Color {
        let rgb = UInt32(hex, radix: 16) ?? 0
        return Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
                     blue: Double(rgb & 255) / 255)
    }
    /// The default accent keeps its designed pair from the asset catalog. A chosen accent is laid over
    /// `background` as a stronger and a fainter tint, so it reads in both light and dark.
    static func onboardingGradient(accentHex: String?) -> (start: Color, end: Color) {
        guard let accentHex else { return (Color(.onboardingStart), Color(.onboardingEnd)) }
        let tint = color(hex: accentHex)
        return (tint.opacity(onboardingStrongTint), tint.opacity(onboardingFaintTint))
    }

    private static let onboardingStrongTint = 0.28
    private static let onboardingFaintTint = 0.08

    /// The accent, slightly see-through, for tinting glass (the hovered wheel petal).
    static var accentGlass: Color {
        InterfaceStyle.shared.preferences.accentHex == nil ? Color(.accentGlass) : accent.opacity(0.65)
    }
    static let danger = Color(.danger)
    /// Hairline edge of glass surfaces (catches the light on any backdrop).
    static let glassEdge = Color(.glassEdge)
    /// A wheel petal's raised surface, its top sheen and its hairline edge.
    static let petal = Color(.petal)
    static let petalSheen = Color(.petalSheen)
    /// The light catching the top of the hovered petal.
    static var highlightSheen: Color { petalSheen.opacity(0.3) }
    /// Dims the image outside the crop box.
    static var cropShade: Color { background.opacity(0.55) }
    static let petalEdge = Color(.petalEdge)
    /// The recessed well in the middle of the wheel, and the pill that names the option.
    static let hubWell = Color(.hubWell)
    static let hubPill = Color(.hubPill)
}
