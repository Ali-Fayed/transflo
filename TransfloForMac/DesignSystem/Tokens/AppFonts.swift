import SwiftUI

/// Maps each `AppTextStyle` to a system font that scales with the user's text size.
enum AppFonts {
    static func font(for style: AppTextStyle) -> Font {
        switch style {
        case .welcomeTitle: .system(size: 28, weight: .semibold)
        case .title: .system(.title3, design: .rounded, weight: .semibold)
        case .headline: .system(.subheadline, design: .rounded, weight: .semibold)
        case .body: .system(.body)
        case .caption: .system(.caption)
        case .captionEmphasis: .system(.caption, weight: .semibold)
        case .wedgeCompact: .system(.caption2, weight: .semibold)
        case .wheelLabel(let size): .system(size: size, weight: .semibold)
        }
    }
}
