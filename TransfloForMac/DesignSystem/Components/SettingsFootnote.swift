import SwiftUI

/// Inline message under a row, e.g. why a change did not apply.
struct SettingsFootnote: View {
    let message: L10nKey
    var tone: AppTextColor = .secondary

    var body: some View {
        AppText(message, style: .caption, color: tone)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
    }
}
