import SwiftUI

/// Hairline between rows inside a `SettingsSection`.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.divider)
            .frame(height: AppDimensions.Stroke.hairline)
    }
}
