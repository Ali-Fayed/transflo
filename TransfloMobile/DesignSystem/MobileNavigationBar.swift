import SwiftUI

/// Leading text titles share the system's safe areas, back navigation and toolbar actions.
private struct MobileNavigationBar: ViewModifier {
    let title: L10nKey
    @Environment(Localizer.self) private var localizer

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .tint(AppColors.accent)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { heading }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { heading }
                }
            }
    }

    private var heading: some View {
        Text(localizer.string(title))
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("mobile.navigation.title")
    }
}

extension View {
    func mobileNavigationBar(_ title: L10nKey) -> some View {
        modifier(MobileNavigationBar(title: title))
    }
}
