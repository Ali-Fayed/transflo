import SwiftUI

/// A localized list swipe action; destructive ones are tinted red by the system.
struct AppSwipeAction: View {
    @Environment(Localizer.self) private var localizer
    let key: L10nKey
    let symbol: AppSymbol
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(role: isDestructive ? .destructive : nil, action: action) {
            Label(localizer.string(key), systemImage: symbol.rawValue)
        }
        .tint(isDestructive ? nil : AppColors.accent)
    }
}
