import SwiftUI

/// The wheel's center: a recessed well holding a white pill that names the hovered option,
/// or the wheel and its key when nothing is hovered.
struct AppWheelHub: View {
    let wellDiameter: CGFloat
    let title: WheelWedgeContent.Label
    let glyph: String?
    var detail: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.hubWell)
                .overlay(Circle().stroke(AppColors.petalEdge, lineWidth: AppDimensions.Stroke.hairline))
                .frame(width: wellDiameter, height: wellDiameter)
            HStack(spacing: AppDimensions.Spacing.xSmall) {
                if let glyph {
                    AppText(verbatim: glyph, style: .headline, color: .accent)
                }
                if let detail {
                    AppText(verbatim: detail, style: .wedgeCompact, color: .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(AppDimensions.Wheel.hubDetailMinScale)
                        .accessibilityIdentifier("transflo.wheel.summary")
                } else {
                    AppWheelLabel(label: title, style: .wedgeCompact, color: .primary,
                                  tracking: AppDimensions.Wheel.hubLabelTracking)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, detail == nil ? AppDimensions.Spacing.large : AppDimensions.Spacing.small)
            .frame(height: AppDimensions.Wheel.hubPillHeight)
            .frame(maxWidth: detail == nil ? wellDiameter - AppDimensions.Spacing.medium
                   : wellDiameter + AppDimensions.Wheel.hubSummaryExtraWidth)
            .background(AppColors.hubPill, in: Capsule())
            .overlay(Capsule().stroke(AppColors.petalEdge, lineWidth: AppDimensions.Stroke.hairline))
            .appShadow(AppShadows.pill)
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("transflo.wheel.hub")
    }
}
