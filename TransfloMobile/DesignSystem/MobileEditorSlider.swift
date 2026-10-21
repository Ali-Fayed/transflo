import SwiftUI

/// Native touch tracking and VoiceOver, with a precise readout and generous hit area.
struct MobileEditorSlider: View {
    let title: L10nKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String
    var resting: Double?
    var onEditingChanged: (Bool) -> Void = { _ in }
    @Environment(Localizer.self) private var localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizer.string(title)).font(.subheadline.weight(.medium))
                Spacer(minLength: 12)
                Text(valueText).font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppColors.accent.opacity(0.08), in: Capsule())
            }
            Slider(value: $value, in: range, onEditingChanged: {
                if !$0 { AppFeedback.selection() }
                onEditingChanged($0)
            })
                .tint(AppColors.accent)
                .frame(minHeight: 44)
                .accessibilityLabel(localizer.string(title))
                .accessibilityValue(valueText)
            if let resting {
                HStack {
                    Text(range.lowerBound.formatted(.number.precision(.fractionLength(2)).locale(localizer.locale)))
                    Spacer()
                    Button(localizer.string(.editorReset)) { value = resting }
                        .buttonStyle(.plain).foregroundStyle(AppColors.accent)
                        .accessibilityLabel(localizer.string(.editorReset) + ": " + localizer.string(title))
                    Spacer()
                    Text(range.upperBound.formatted(.number.precision(.fractionLength(2)).locale(localizer.locale)))
                }
                .font(.caption).foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}
