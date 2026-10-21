import SwiftUI

/// The running app's own icon, popping in when it first appears.
struct AppAppIcon: View {
    let size: CGFloat
    @State private var shown = false

    var body: some View {
        AppPlatform.appIcon
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * AppPlatform.appIconCornerFraction, style: .continuous))
            .scaleEffect(shown ? 1 : AppDimensions.Onboarding.popScale)
            .opacity(shown ? 1 : 0)
            .accessibilityHidden(true)
            .onAppear {
                guard let animation = AppAnimations.heroPop else {
                    shown = true
                    return
                }
                withAnimation(animation) { shown = true }
            }
    }
}
