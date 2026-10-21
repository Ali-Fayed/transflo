import SwiftUI

/// A decorative keycap; surrounding copy supplies the instruction and accessible key name.
/// With `demonstratesTap`, it presses itself every couple of seconds to show the gesture.
struct AppKeycap: View {
    let glyph: String
    var demonstratesTap = false

    var body: some View {
        if demonstratesTap, let press = AppAnimations.keycapPress, let release = AppAnimations.keycapRelease {
            face(pressed: false)
                .phaseAnimator([false, true]) { _, pressed in
                    face(pressed: pressed)
                } animation: { pressed in
                    pressed ? press : release
                }
        } else {
            face(pressed: false)
        }
    }

    private func face(pressed: Bool) -> some View {
        AppText(verbatim: glyph, style: .title)
            .frame(width: AppDimensions.Onboarding.keycapWidth, height: AppDimensions.Onboarding.keycapHeight)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
            .overlay(RoundedRectangle(cornerRadius: AppDimensions.Radius.small)
                .strokeBorder(pressed ? AppColors.accent : AppColors.divider))
            .scaleEffect(pressed ? AppDimensions.Onboarding.keycapPressedScale : 1)
            .offset(y: pressed ? AppDimensions.Onboarding.keycapPressDepth : 0)
    }
}
