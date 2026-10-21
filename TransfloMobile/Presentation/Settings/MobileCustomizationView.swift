import SwiftUI
import TransfloDomain

/// Settings › Customization: color, wheel, effects and feedback, each in its own section, like About.
struct MobileCustomizationView: View {
    let customization: CustomizationViewModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: AppDimensions.Spacing.large) {
                    AppFlowMark(size: AppDimensions.Flow.previewMark, animated: false)
                    AppText(.mobileColorDetail, style: .caption, color: .secondary)
                }
                .padding(.vertical, AppDimensions.Spacing.small)
                AppAccentPicker(selection: binding(\.accentHex))
                    .padding(.vertical, AppDimensions.Spacing.small)
            }
            Section {
                toggleRow(.settingsLiquidGlass, isOn: liquidGlass)
                toggleRow(.settingsReduceMotion, isOn: binding(\.reduceMotion))
                toggleRow(.settingsWheelHaptics, isOn: binding(\.wheelHaptics))
            } header: {
                AppText(.settingsAccessibility, style: .caption, color: .secondary)
            }
            Section {
                AppButton(key: .settingsResetCustomization, variant: .tertiary) {
                    customization.reset()
                }
                .accessibilityIdentifier("mobile.customization.reset")
            }
        }
        .appScreenBackground()
        .tint(AppColors.accent)
        .mobileNavigationBar(.settingsCustomization)
        .accessibilityIdentifier("mobile.customization")
    }

    private func toggleRow(_ key: L10nKey, isOn: Binding<Bool>) -> some View {
        HStack {
            AppText(key)
            Spacer(minLength: AppDimensions.Spacing.medium)
            AppToggle(key: key, isOn: isOn)
        }
    }

    private var liquidGlass: Binding<Bool> {
        Binding(get: { !customization.preferences.solidSurfaces }, set: { enabled in
            customization.update { $0.solidSurfaces = !enabled }
        })
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<InterfaceCustomization, Value>) -> Binding<Value> {
        Binding(get: { customization.preferences[keyPath: keyPath] }, set: { value in
            customization.update { $0[keyPath: keyPath] = value }
            if keyPath == \.accentHex { AppFeedback.selection() }
        })
    }
}
