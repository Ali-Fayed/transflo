import SwiftUI

/// A row of color dots; the selected one carries an accent ring.
struct AppColorSwatches: View {
    @Environment(Localizer.self) private var localizer
    @Binding var selection: String
    var swatches = AppMarkupPalette.swatches

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.small) {
            ForEach(swatches) { swatch in
                let isSelected = selection.caseInsensitiveCompare(swatch.hex) == .orderedSame
                Button { selection = swatch.hex } label: {
                    Circle()
                        .fill(AppMarkupPalette.color(swatch.hex))
                        .overlay(Circle().strokeBorder(AppColors.divider, lineWidth: AppDimensions.Stroke.hairline))
                        .padding(AppDimensions.Editor.swatchRingGap)
                        .overlay(Circle()
                            .strokeBorder(AppColors.accent, lineWidth: AppDimensions.Stroke.selection)
                            .opacity(isSelected ? 1 : 0))
                        .frame(width: AppDimensions.Editor.swatchSize, height: AppDimensions.Editor.swatchSize)
                }
                .buttonStyle(.plain)
                .appFocusRing(Circle())
                .accessibilityLabel(localizer.string(swatch.label))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
