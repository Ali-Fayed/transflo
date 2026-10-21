import SwiftUI

/// One metadata field: its name over its selectable value.
struct AppMetadataEntry: View {
    let name: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
            AppText(verbatim: name, style: .captionEmphasis)
            AppText(verbatim: value, style: .caption)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
