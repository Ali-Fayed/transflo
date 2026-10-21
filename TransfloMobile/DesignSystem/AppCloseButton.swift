import SwiftUI

struct AppCloseButton: View {
    @Environment(Localizer.self) private var localizer
    var label: L10nKey = .editorCancel
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button { AppFeedback.selection(); action() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 44, height: 44)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.divider, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(localizer.string(label))
        .accessibilityIdentifier("mobile.sheet.close")
    }
}

/// Prevents the system from wrapping our custom close control in another glass button.
struct MobileCloseToolbar: ToolbarContent {
    var isEnabled = true
    let action: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) {
                AppCloseButton(isEnabled: isEnabled, action: action)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                AppCloseButton(isEnabled: isEnabled, action: action)
            }
        }
    }
}
