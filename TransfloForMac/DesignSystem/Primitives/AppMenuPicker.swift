import SwiftUI

/// A pop-up menu of choices, for lists too long for a segmented control. Labels are copy or data.
struct AppMenuPicker<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: AppTextContent
        var id: Value { value }

        init(value: Value, label: L10nKey) {
            self.value = value
            self.label = .key(label)
        }

        /// A label that is data, such as a format name ("JPG").
        init(value: Value, verbatim: String) {
            self.value = value
            self.label = .verbatim(verbatim)
        }

        /// A label built from copy and data, such as "Convert to JPG".
        init(value: Value, content: AppTextContent) {
            self.value = value
            self.label = content
        }
    }

    @Environment(Localizer.self) private var localizer
    let key: L10nKey
    @Binding var selection: Value
    let options: [Option]
    var width: CGFloat = AppDimensions.Editor.menuPickerWidth

    var body: some View {
        Picker(localizer.string(key), selection: $selection) {
            ForEach(options) { option in
                Text(localizer.string(option.label)).tag(option.value)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: width)
    }
}
