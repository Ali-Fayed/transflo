import SwiftUI

/// A search field whose placeholder is localized copy; `placeholder` also labels it for VoiceOver.
struct AppSearchField: View {
    @Environment(Localizer.self) private var localizer
    let placeholder: L10nKey
    @Binding var text: String

    var body: some View {
        TextField(localizer.string(placeholder), text: $text)
            .textFieldStyle(.roundedBorder)
            .appFocusRing(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
    }
}
