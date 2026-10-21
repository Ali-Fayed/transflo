import SwiftUI

/// A labeled whole-number field with a stepper, limited to `range`.
struct AppNumberField: View {
    @Environment(Localizer.self) private var localizer
    let label: L10nKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: L10nKey?
    var rejectsBelowMinimum = false

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.small) {
            // The label keeps its width before the spacer gives any up, so it never wraps word by word.
            AppText(label)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: AppDimensions.Spacing.small)
            TextField(localizer.string(label), value: clamped, format: .number)
                .textFieldStyle(.roundedBorder)
                .appFocusRing(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
                .multilineTextAlignment(.trailing)
                .frame(width: AppDimensions.Editor.fieldWidth)
                .labelsHidden()
            if let unit { AppText(unit, color: .secondary) }
            Stepper(localizer.string(label), value: clamped, in: range)
                .labelsHidden()
        }
    }

    private var clamped: Binding<Int> {
        Binding(get: { value }, set: {
            guard !rejectsBelowMinimum || $0 >= range.lowerBound else { return }
            value = min(max($0, range.lowerBound), range.upperBound)
        })
    }
}
