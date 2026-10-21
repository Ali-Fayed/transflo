import SwiftUI

/// Named accent presets and the native macOS color panel, with opaque RGB storage.
struct AppAccentPicker: View {
    @Binding var selection: String?
    @Environment(Localizer.self) private var localizer

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(.settingsAccentColor)
            HStack(spacing: AppDimensions.Spacing.medium) {
                ForEach(Self.presets, id: \.name) { preset in
                    Button { selection = preset.hex } label: {
                        Circle()
                            .fill(preset.hex.map(AppColors.color(hex:)) ?? Color(.accent))
                            .frame(width: Self.swatch, height: Self.swatch)
                            .overlay(Circle().strokeBorder(AppColors.divider))
                            .padding(AppDimensions.Editor.swatchRingGap)
                            .overlay(Circle().strokeBorder(selection == preset.hex ? AppColors.textPrimary : .clear,
                                                           lineWidth: AppDimensions.Stroke.selection))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .appFocusRing(Circle())
                    .accessibilityLabel(localizer.string(preset.name))
                    .accessibilityAddTraits(selection == preset.hex ? .isSelected : [])
                    .help(localizer.string(preset.name))
                }
                Spacer(minLength: 0)
                ColorPicker(localizer.string(.settingsCustomColor), selection: color, supportsOpacity: false)
                    .labelsHidden()
                    .accessibilityIdentifier("settings.customColor")
            }
        }
    }

    private var color: Binding<Color> {
        Binding(get: { selection.map(AppColors.color(hex:)) ?? Color(.accent) }, set: { color in
            guard let hex = AppPlatform.hex(color) else { return }
            selection = hex
        })
    }

    private static let swatch = AppDimensions.Window.accentSwatchSize

    private static let presets: [(name: L10nKey, hex: String?)] = [
        (.settingsColorDefault, nil), (.settingsColorBlue, "2563EB"), (.settingsColorViolet, "7C3AED"),
        (.settingsColorRose, "BE185D"), (.settingsColorOrange, "C2410C"), (.settingsColorGreen, "15803D")
    ]
}
