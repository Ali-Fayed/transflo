import SwiftUI
import TransfloDomain

/// The Watch Folders section: each folder with its action and an on/off switch, and Add Folder.
struct WatchFoldersSettingsView: View {
    let model: WatchFoldersViewModel

    var body: some View {
        SettingsSection(title: .watchFolders) {
            SettingsFootnote(message: .watchFoldersHint)
            if model.folders.isEmpty {
                AppText(.watchFoldersEmpty, color: .secondary)
            }
            ForEach(model.folders) { folder in
                SettingsDivider()
                VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
                    HStack(spacing: AppDimensions.Spacing.small) {
                        AppIcon(symbol: .move)
                        AppText(verbatim: folder.folder.lastPathComponent, style: .headline)
                            .truncationMode(.middle)
                            .lineLimit(1)
                        Spacer(minLength: AppDimensions.Spacing.small)
                        AppToggle(key: .watchEnabled, isOn: Binding(
                            get: { folder.isEnabled }, set: { model.setEnabled(folder.id, $0) }))
                        AppIconButton(symbol: .remove, label: .watchRemove) { model.remove(folder.id) }
                    }
                    HStack(spacing: AppDimensions.Spacing.small) {
                        AppText(.watchNewFiles, style: .caption, color: .secondary)
                        AppMenuPicker(key: .watchNewFiles, selection: Binding(
                            get: { folder.action }, set: { model.setAction(folder.id, $0) }
                        ), options: model.actions.map { .init(value: $0.action, content: $0.label) })
                    }
                }
            }
            SettingsDivider()
            AppButton(key: .watchAdd, variant: .tertiary) { Task { await model.addFolder() } }
                .accessibilityIdentifier("settings.watch.add")
        }
    }
}
