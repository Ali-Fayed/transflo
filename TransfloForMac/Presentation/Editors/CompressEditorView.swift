import SwiftUI
import TransfloDomain

/// Compress: the file, its size, and Best, Balanced or Smaller. Nothing larger than the original is kept.
struct CompressEditorView: View {
    @Environment(Localizer.self) private var localizer
    @Bindable var model: CompressEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.large) {
            if let name = model.fileName {
                AppText(verbatim: name, style: .caption, color: .secondary).lineLimit(2)
            } else {
                AppText(.jobFileCount, arguments: [String(model.itemCount)], color: .secondary)
            }
            if let bytes = model.originalBytes {
                HStack {
                    AppText(.compressionOriginalSize, color: .secondary)
                    Spacer()
                    AppText(verbatim: FileByteSizeFormatter().string(bytes: bytes, locale: localizer.locale))
                        .monospacedDigit()
                }
            }
            AppChipGroup(key: .compressionPreset, selection: $model.level, options: [
                .init(value: .light, label: .compressionLight), .init(value: .medium, label: .compressionMedium),
                .init(value: .strong, label: .compressionStrong)
            ])
            SettingsFootnote(message: model.isPDF ? .compressionPDFHint : .compressionPresetHint)
        }
    }
}
