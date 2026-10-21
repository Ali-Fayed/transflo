import SwiftUI

/// Renders an `AppSymbol`. Decorative unless an accessibility label is given.
struct AppIcon: View {
    @Environment(Localizer.self) private var localizer
    let symbol: AppSymbol
    var size: CGFloat = AppDimensions.IconSize.medium
    var accessibilityLabel: L10nKey?

    var body: some View {
        Image(systemName: symbol.rawValue)
            .font(.system(size: size))
            .accessibilityLabel(accessibilityLabel.map { localizer.string($0) } ?? "")
            .accessibilityHidden(accessibilityLabel == nil)
    }
}
