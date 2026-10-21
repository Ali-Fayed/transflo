import SwiftUI

/// Root wrapper that injects the `Localizer`, locale and layout direction into a view tree.
///
/// Reading the localizer inside `body` keeps the tree reactive: switching language
/// re-renders every `App*` primitive and flips RTL/LTR immediately.
struct AppLocalizedRoot<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let localizer: Localizer
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .tint(AppColors.accent)
            .transaction { transaction in
                if reduceMotion || InterfaceStyle.shared.preferences.reduceMotion {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
            .environment(localizer)
            .environment(\.locale, localizer.locale)
            .environment(\.layoutDirection, localizer.layoutDirection)
    }
}
