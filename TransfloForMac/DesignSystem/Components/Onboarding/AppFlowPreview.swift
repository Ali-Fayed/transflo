import SwiftUI
import TransfloDomain

/// A clearly labeled, local-only demonstration. Tapping the wheel previews a PNG choice.
struct AppFlowPreview: View {
    let stage: Int
    @Environment(Localizer.self) private var localizer
    @State private var converted = false

    var body: some View {
        VStack(spacing: AppDimensions.Spacing.xLarge) {
            if stage == 1 {
                demoWheel
            } else {
                AppFlowMark(size: AppDimensions.Flow.heroMark)
            }
            HStack(spacing: AppDimensions.Spacing.large) {
                AppIcon(symbol: stage == 2 ? .shareJob : .flowFile, size: AppDimensions.IconSize.medium)
                    .foregroundStyle(AppColors.accent)
                AppText(verbatim: stage == 2 || converted ? "Transflo.png" : "Transflo.heic", style: .headline)
                if stage == 2 || converted {
                    AppIcon(symbol: .success).foregroundStyle(AppColors.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(AppDimensions.Spacing.large)
            .frame(minWidth: AppDimensions.Flow.fileWidth)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppDimensions.Flow.fileCorner))
            if stage == 1 {
                AppText(converted ? .flowDemoResult : .flowDemoAction, style: .caption, color: .secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .animation(AppAnimations.standard, value: converted)
    }

    private var demoWheel: some View {
        let formats = ["PNG", "JPG", "PDF", "TIFF", "BMP", "AVIF"]
        return AppRadialWheel(wedges: formats.map {
            WheelWedgeContent(id: $0, label: .verbatim($0), symbol: nil)
        }, geometry: WheelGeometry(wedgeCount: formats.count,
                                   innerRadius: AppDimensions.Wheel.innerRadius,
                                   outerRadius: AppDimensions.Wheel.compactOuterRadius,
                                   isRightToLeft: localizer.isRightToLeft),
                             highlightedIndex: converted ? 0 : nil, hubTitle: .wheelConvert, hubGlyph: "")
            .onTapGesture { converted.toggle() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(localizer.string(converted ? .flowDemoResult : .flowDemoAction))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { converted.toggle() }
            .accessibilityIdentifier("onboarding.demoWheel")
    }
}
