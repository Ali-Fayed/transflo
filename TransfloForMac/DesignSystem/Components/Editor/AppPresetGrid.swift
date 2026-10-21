import SwiftUI
import TransfloDomain

/// Gradient choices use the same color data as the compositor, with localized accessible names.
struct AppPresetGrid: View {
    @Environment(Localizer.self) private var localizer
    let fill: TransfloDomain.BackgroundStyle.Fill
    let select: (BackgroundPreset) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: AppDimensions.Beautify.presetWidth),
                                     spacing: AppDimensions.Spacing.small)], spacing: AppDimensions.Spacing.small) {
            ForEach(AppBackgroundPresets.all, id: \.self) { preset in
                Button { select(preset) } label: {
                    RoundedRectangle(cornerRadius: AppDimensions.Radius.small)
                        .fill(AppBackgroundPresets.gradient(preset))
                        .frame(height: AppDimensions.Beautify.presetHeight)
                        .overlay(RoundedRectangle(cornerRadius: AppDimensions.Radius.small)
                            .strokeBorder(fill == .gradient(preset) ? AppColors.accent : AppColors.divider,
                                          lineWidth: AppDimensions.Stroke.selection))
                }
                .buttonStyle(.plain)
                .appFocusRing(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
                .accessibilityLabel(localizer.string(AppBackgroundPresets.label(preset)))
                .accessibilityAddTraits(fill == .gradient(preset) ? [.isSelected] : [])
                .accessibilityIdentifier("transflo.background.\(preset.rawValue)")
            }
        }
    }
}
