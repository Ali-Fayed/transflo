import SwiftUI

/// A locale-aware numeric field; invalid text never reaches the bound model.
struct AppDecimalNumberField: View {
    @Environment(Localizer.self) private var localizer
    let label: L10nKey
    let unit: L10nKey
    @Binding var value: Double
    var identifier = "transflo.compression.target"
    var precision = 2

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.small) {
            AppText(label)
            Spacer()
            TextField(localizer.string(label), value: $value,
                      format: .number.precision(.fractionLength(0...precision)))
                .textFieldStyle(.roundedBorder)
                .appFocusRing(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
                .multilineTextAlignment(.trailing)
                .frame(width: AppDimensions.Editor.fieldWidth)
                .accessibilityLabel(localizer.string(label))
                .accessibilityIdentifier(identifier)
            AppText(unit, color: .secondary)
        }
    }
}
