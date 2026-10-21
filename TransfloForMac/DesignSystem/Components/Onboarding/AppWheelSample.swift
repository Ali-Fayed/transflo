import SwiftUI
import TransfloDomain

/// Uses the production wheel without pointer handling, selection, or redundant accessibility nodes.
/// It spins into place, turning with the reading direction, each time its page opens.
struct AppWheelSample: View {
    let wedges: [WheelWedgeContent]
    let title: L10nKey
    let glyph: String
    var highlightedIndex: Int?
    @Environment(Localizer.self) private var localizer
    @State private var shown = false

    var body: some View {
        AppRadialWheel(wedges: wedges, geometry: WheelGeometry(
            wedgeCount: wedges.count, innerRadius: AppDimensions.Wheel.innerRadius,
            outerRadius: AppDimensions.Wheel.compactOuterRadius, isRightToLeft: localizer.isRightToLeft
        ), highlightedIndex: highlightedIndex, hubTitle: title, hubGlyph: glyph,
                       hubDetail: FileByteSizeFormatter().string(bytes: 2_400_000, locale: localizer.locale))
        .scaleEffect(shown ? 1 : AppDimensions.Onboarding.wheelStartScale)
        .rotationEffect(.degrees(shown ? 0 : startTurn))
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard let animation = AppAnimations.heroPop else {
                shown = true
                return
            }
            withAnimation(animation) { shown = true }
        }
    }

    private var startTurn: Double {
        localizer.isRightToLeft ? AppDimensions.Onboarding.wheelStartTurn : -AppDimensions.Onboarding.wheelStartTurn
    }
}
