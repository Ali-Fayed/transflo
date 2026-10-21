import SwiftUI

/// Exact seconds alongside draggable handles; editors validate the range against source duration.
struct AppTimeRangeFields: View {
    @Binding var start: Double
    @Binding var end: Double
    var body: some View {
        VStack(spacing: AppDimensions.Spacing.small) {
            AppDecimalNumberField(label: .editorStartTime, unit: .unitSeconds, value: $start,
                                  identifier: "transflo.time.start", precision: 3)
            AppDecimalNumberField(label: .editorEndTime, unit: .unitSeconds, value: $end,
                                  identifier: "transflo.time.end", precision: 3)
            SettingsFootnote(message: .editorValidTimeHint)
        }
    }
}
