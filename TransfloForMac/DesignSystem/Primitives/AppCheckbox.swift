import SwiftUI

/// A labelled checkbox: a rounded square that fills with the accent and shows a tick when on.
/// Built on `Toggle`, so VoiceOver reads it as a checkbox with its state.
struct AppCheckbox: View {
    let label: AppTextContent
    var symbol: AppSymbol?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: AppDimensions.Spacing.small) {
                if let symbol {
                    AppIcon(symbol: symbol, size: AppDimensions.IconSize.medium)
                        .foregroundStyle(AppColors.textSecondary)
                }
                AppText(label)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .toggleStyle(AppCheckboxStyle())
    }
}

/// Draws the box and makes the whole row clickable.
private struct AppCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(AppAnimations.checkbox) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: AppDimensions.Spacing.small) {
                box(isOn: configuration.isOn)
                configuration.label
                Spacer(minLength: .zero)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appFocusRing(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
        .accessibilityRepresentation {
            #if os(macOS)
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.checkbox)
            #else
            Toggle(isOn: configuration.$isOn) { configuration.label }
            #endif
        }
    }

    private func box(isOn: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppDimensions.Checkbox.radius)
        return shape
            .fill(isOn ? AppColors.accent : Color.clear)
            .overlay(shape.strokeBorder(isOn ? AppColors.accent : AppColors.divider,
                                        lineWidth: AppDimensions.Stroke.hairline))
            .overlay {
                AppIcon(symbol: .success, size: AppDimensions.Checkbox.checkSize)
                    .foregroundStyle(AppColors.accentContrast)
                    .scaleEffect(isOn ? 1 : 0.4)
                    .opacity(isOn ? 1 : 0)
            }
            .frame(width: AppDimensions.Checkbox.size, height: AppDimensions.Checkbox.size)
    }
}
