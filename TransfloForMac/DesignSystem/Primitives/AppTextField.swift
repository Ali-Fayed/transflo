import SwiftUI

/// A labeled single-line text field.
struct AppTextField: View {
    @Environment(Localizer.self) private var localizer
    let label: AppTextContent
    @Binding var text: String

    init(label: L10nKey, text: Binding<String>) {
        self.init(content: .key(label), text: text)
    }

    /// A field labeled with data, such as the file it edits a name for.
    init(content: AppTextContent, text: Binding<String>) {
        self.label = content
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
            AppText(label)
            TextField(localizer.string(label), text: $text)
                .textFieldStyle(.roundedBorder)
                .appFocusRing(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
                .labelsHidden()
        }
    }
}
