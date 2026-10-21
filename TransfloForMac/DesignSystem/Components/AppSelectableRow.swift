import SwiftUI

/// A full-width list row that fills with the accent when selected, as in a source list.
struct AppSelectableRow: View {
    let label: AppTextContent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppText(label, style: .body, color: isSelected ? .onAccent : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppDimensions.Spacing.small)
                .background(isSelected ? AppColors.accent : .clear,
                            in: RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appFocusRing(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
