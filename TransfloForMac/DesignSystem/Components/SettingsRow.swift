import SwiftUI

/// A label on the leading edge with its control on the trailing edge.
struct SettingsRow<Trailing: View>: View {
    let label: L10nKey
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.medium) {
            AppText(label)
            Spacer(minLength: AppDimensions.Spacing.large)
            trailing()
        }
    }
}
