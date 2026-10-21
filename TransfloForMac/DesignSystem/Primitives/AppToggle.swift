import SwiftUI

/// A switch whose visible label is provided by the surrounding row; `key` labels it for VoiceOver.
struct AppToggle: View {
    @Environment(Localizer.self) private var localizer
    let key: L10nKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(localizer.string(key), isOn: $isOn)
            .onChange(of: isOn) { _, _ in AppFeedback.selection() }
            .toggleStyle(.switch)
            .tint(AppColors.accent)
            .labelsHidden()
            .appFocusRing(Capsule())
    }
}
