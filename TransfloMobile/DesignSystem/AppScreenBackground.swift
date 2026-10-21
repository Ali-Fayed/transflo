import SwiftUI

/// Every iPhone and iPad screen sits on the same warm background as Home, lists and forms included.
private struct AppScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
    }
}

extension View {
    /// The app's screen background, replacing the system's grouped gray behind lists and forms.
    func appScreenBackground() -> some View {
        modifier(AppScreenBackground())
    }
}
