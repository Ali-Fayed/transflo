import SwiftUI

/// A multi-line text box with the standard border; `label` names it for VoiceOver.
struct AppTextEditor: View {
    @Environment(Localizer.self) private var localizer
    let label: L10nKey
    @Binding var text: String
    var height: CGFloat = AppDimensions.Editor.textEditorHeight

    var body: some View {
        TextEditor(text: $text)
            .font(AppFonts.font(for: .body))
            .frame(height: height)
            .overlay(RoundedRectangle(cornerRadius: AppDimensions.Radius.small)
                .strokeBorder(AppColors.divider, lineWidth: AppDimensions.Stroke.hairline))
            .appFocusRing(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
            .accessibilityLabel(localizer.string(label))
    }
}
