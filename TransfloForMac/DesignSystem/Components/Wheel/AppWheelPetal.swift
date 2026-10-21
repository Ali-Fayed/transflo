import SwiftUI

/// One option on the wheel: a soft raised petal with its icon above an uppercase label.
/// The highlighted petal turns into accent-tinted Liquid Glass (a solid accent before macOS 26).
struct AppWheelPetal: View {
    let shape: WheelPetalShape
    let content: WheelWedgeContent
    let isHighlighted: Bool
    let metrics: WheelLabelMetrics
    let labelOffset: CGSize

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(Localizer.self) private var localizer

    var body: some View {
        ZStack {
            surface
            label.offset(labelOffset)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(localizer.string(content.id.hasPrefix("group.") ? .wheelGroupHint
            : (content.id == "back" ? .wheelBackHint : .wheelPetalHint)))
    }

    @ViewBuilder private var surface: some View {
        if isHighlighted {
            highlightedSurface
        } else {
            shape
                .fill(LinearGradient(colors: [AppColors.petalSheen, AppColors.petal],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(shape.stroke(AppColors.petalEdge, lineWidth: AppDimensions.Stroke.hairline))
                .appShadow(AppShadows.petal)
        }
    }

    @ViewBuilder private var highlightedSurface: some View {
        if InterfaceStyle.shared.preferences.solidSurfaces || reduceTransparency
            || InterfaceStyle.shared.preferences.accentHex != nil {
            shape.fill(AppColors.accent).appShadow(AppShadows.pill)
        } else if #available(macOS 26.0, iOS 26.0, *) {
            // Translucent accent over Liquid Glass: the tint reads clearly and the glass edge shows.
            shape.fill(AppColors.accentGlass)
                .overlay(shape.fill(LinearGradient(colors: [AppColors.highlightSheen, .clear],
                                                   startPoint: .top, endPoint: .center)))
                .glassEffect(.regular.interactive(), in: shape)
                .appShadow(AppShadows.pill)
        } else {
            shape
                .fill(AppColors.accent)
                .overlay(shape.fill(LinearGradient(colors: [AppColors.highlightSheen, .clear],
                                                   startPoint: .top, endPoint: .center)))
                .appShadow(AppShadows.pill)
        }
    }

    private var label: some View {
        let color: AppTextColor = isHighlighted ? .onAccent : .primary
        return VStack(spacing: metrics.spacing) {
            if let symbol = content.symbol {
                AppIcon(symbol: symbol, size: metrics.iconSize)
                    .foregroundStyle(color.color)
            }
            AppWheelLabel(label: content.label, style: .wheelLabel(size: metrics.fontSize), color: color,
                          tracking: metrics.tracking)
        }
        .frame(width: metrics.width)
        .fixedSize(horizontal: false, vertical: true)
    }
}
