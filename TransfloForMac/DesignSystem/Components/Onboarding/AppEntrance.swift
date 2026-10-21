import SwiftUI

/// Fades content up into place when it appears, `step` beats after its page opens. With reduced
/// motion the content is simply there.
struct AppEntrance: ViewModifier {
    let step: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : AppDimensions.Onboarding.entranceOffset)
            .onAppear {
                guard let animation = AppAnimations.entrance else {
                    shown = true
                    return
                }
                withAnimation(animation.delay(Double(step) * AppAnimations.entranceStep)) { shown = true }
            }
    }
}

extension View {
    /// Staggered entrance; see `AppEntrance`.
    func appEntrance(step: Int) -> some View { modifier(AppEntrance(step: step)) }
}
