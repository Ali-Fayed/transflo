import SwiftUI
import TransfloDomain

/// Appearance preferences used once in General; wheel geometry lives in Wheels.
struct CustomizationSettingsView: View {
    let settings: SettingsViewModel
    let viewModel: CustomizationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xLarge) {
            SettingsSection(title: .settingsAppearance) {
                SettingsRow(label: .settingsAppearance) {
                    AppSegmentedPicker(key: .settingsAppearance, selection: appearance, options: Self.appearances,
                                       width: AppDimensions.Window.settingsControlWidth)
                }
                SettingsDivider()
                AppAccentPicker(selection: binding(\.accentHex))
                HStack(spacing: AppDimensions.Spacing.large) {
                    AppFlowMark(size: AppDimensions.Flow.previewMark, animated: false)
                    AppText(.flowColorDetail, style: .caption, color: .secondary)
                }
            }
            SettingsSection(title: .settingsAccessibility) {
                SettingsRow(label: .settingsLiquidGlass) {
                    AppToggle(key: .settingsLiquidGlass, isOn: liquidGlass)
                }
                SettingsDivider()
                SettingsRow(label: .settingsReduceMotion) {
                    AppToggle(key: .settingsReduceMotion, isOn: binding(\.reduceMotion))
                }
            }
            AppButton(key: .settingsResetAppearance, variant: .tertiary) {
                viewModel.update { $0.accentHex = nil; $0.solidSurfaces = false; $0.reduceMotion = false }
                settings.selectAppearance(.system)
            }
        }
    }

    private var liquidGlass: Binding<Bool> {
        Binding(get: { !viewModel.preferences.solidSurfaces }, set: { enabled in
            viewModel.update { $0.solidSurfaces = !enabled }
        })
    }

    private var appearance: Binding<AppearanceMode> {
        Binding(get: { settings.state.appearance }, set: { settings.selectAppearance($0) })
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<InterfaceCustomization, Value>) -> Binding<Value> {
        Binding(get: { viewModel.preferences[keyPath: keyPath] }, set: { value in
            viewModel.update { $0[keyPath: keyPath] = value }
        })
    }

    private static let appearances: [AppSegmentedPicker<AppearanceMode>.Option] = [
        .init(value: .system, label: .appearanceSystem), .init(value: .light, label: .appearanceLight),
        .init(value: .dark, label: .appearanceDark)
    ]
}
