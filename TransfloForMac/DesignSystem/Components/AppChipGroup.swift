import SwiftUI

/// A wrapping, keyboard-focusable choice group using Transflo's glass and accent tokens.
struct AppChipGroup<Value: Hashable>: View {
    @Environment(\.layoutDirection) private var direction
    @Environment(Localizer.self) private var localizer
    let key: L10nKey
    @Binding var selection: Value
    let options: [AppSegmentedPicker<Value>.Option]

    var body: some View {
        AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: direction == .rightToLeft) {
            ForEach(options) { option in
                Button { selection = option.value } label: {
                    AppText(option.label, style: .caption,
                            color: selection == option.value ? .onAccent : .primary)
                        .padding(.horizontal, AppDimensions.Spacing.medium)
                        .padding(.vertical, AppDimensions.Spacing.small)
                        .background(selection == option.value ? AppColors.accent : .clear, in: Capsule())
                        .appGlass(.card, in: Capsule())
                }
                .buttonStyle(.plain)
                .appFocusRing(Capsule(), focusable: true)
                .environment(\.layoutDirection, direction)
                .accessibilityAddTraits(selection == option.value ? [.isSelected] : [])
                .accessibilityIdentifier("transflo.chip.\(option.label.rawValue)")
            }
        }
        // Placement above already mirrors; avoid a second automatic layout mirror.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localizer.string(key))
    }
}
