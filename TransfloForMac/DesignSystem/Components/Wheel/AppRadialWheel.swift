import SwiftUI
import TransfloDomain

/// The radial wheel: separate rounded petals on a glass disc around a hub whose pill names the
/// hovered option (or the wheel and its key).
///
/// Layout comes from `WheelGeometry`, which also does hit-testing, so what is drawn and what
/// is dropped on always agree (including the right-to-left mirror). The ring's size comes from
/// the geometry too, so it grows with the number of options.
struct AppRadialWheel: View {
    let wedges: [WheelWedgeContent]
    let geometry: WheelGeometry
    let highlightedIndex: Int?
    let hubTitle: L10nKey
    let hubGlyph: String
    var hubDetail: String?
    var itemCount = 1
    var onActivate: ((Int) -> Void)?

    var body: some View {
        ZStack {
            ForEach(Array(wedges.enumerated()), id: \.element.id) { index, wedge in
                AppWheelPetal(
                    shape: petal(at: index),
                    content: wedge,
                    isHighlighted: index == highlightedIndex,
                    metrics: metrics,
                    labelOffset: labelOffset(forWedge: index)
                )
                .frame(width: outerDiameter, height: outerDiameter)
                #if os(iOS)
                .contentShape(petal(at: index))
                .onTapGesture { onActivate?(index) }
                .accessibilityActivationPoint(UnitPoint(
                    x: 0.5 + labelOffset(forWedge: index).width / outerDiameter,
                    y: 0.5 + labelOffset(forWedge: index).height / outerDiameter
                ))
                #endif
                .accessibilityAction { onActivate?(index) }
            }
            AppWheelHub(
                wellDiameter: (geometry.innerRadius - AppDimensions.Wheel.petalGap) * 2,
                title: hubLabel,
                glyph: highlightedIndex == nil ? hubGlyph : nil,
                detail: highlightedIndex == nil ? hubDetail : nil
            )
            .overlay(alignment: geometry.isRightToLeft ? .topLeading : .topTrailing) {
                if itemCount > 1 { AppCountBadge(count: itemCount) }
            }
        }
        .frame(width: outerDiameter, height: outerDiameter)
        .background(Circle().fill(.clear).appGlass(.floating, in: Circle()))
        .padding(AppDimensions.Wheel.margin)
        // Geometry already mirrors for RTL; stop SwiftUI from mirroring offsets a second time.
        .environment(\.layoutDirection, .leftToRight)
        .animation(AppAnimations.wheelHighlight, value: highlightedIndex)
    }

    private var outerDiameter: CGFloat { geometry.outerRadius * 2 }
    private var metrics: WheelLabelMetrics {
        WheelLabelMetrics(
            geometry: geometry,
            petalInset: AppDimensions.Wheel.petalInset,
            gap: AppDimensions.Wheel.petalGap,
            sideInset: AppDimensions.Wheel.labelInset
        )
    }

    private var hubLabel: WheelWedgeContent.Label {
        guard let index = highlightedIndex, wedges.indices.contains(index) else { return .key(hubTitle) }
        return wedges[index].label
    }

    private func petal(at index: Int) -> WheelPetalShape {
        WheelPetalShape(
            centerAngle: geometry.centerAngle(ofWedge: index),
            span: geometry.wedgeSpan,
            innerRadius: geometry.innerRadius,
            outerRadius: geometry.outerRadius - AppDimensions.Wheel.petalInset,
            gap: AppDimensions.Wheel.petalGap,
            cornerRadius: AppDimensions.Wheel.petalCornerRadius
        )
    }

    private func labelOffset(forWedge index: Int) -> CGSize {
        let radius = metrics.radius
        let radians = geometry.centerAngle(ofWedge: index) * .pi / 180
        return CGSize(width: radius * sin(radians), height: -radius * cos(radians))
    }
}
