import SwiftUI

/// Wheel text: uppercase with a little tracking, up to two lines, shrinking slightly if needed.
struct AppWheelLabel: View {
    let label: WheelWedgeContent.Label
    let style: AppTextStyle
    let color: AppTextColor
    let tracking: CGFloat

    var body: some View {
        Group {
            switch label {
            case .key(let key): AppText(key, style: style, color: color)
            case .verbatim(let text): AppText(verbatim: text, style: style, color: color)
            }
        }
        .textCase(.uppercase)
        .tracking(tracking)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
    }
}
