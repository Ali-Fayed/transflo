import SwiftUI
import TransfloDomain

struct MetadataRemovalEditorView: View {
    @Bindable var model: MetadataRemovalEditorViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(.metadataRemovalHint, style: .caption, color: .secondary)
            ForEach(MetadataCategory.allCases, id: \.self) { category in
                SettingsRow(label: Self.label(category)) {
                    AppToggle(key: Self.label(category), isOn: Binding(get: { model.selected.contains(category) },
                                                                     set: { _ in model.toggle(category) }))
                }
            }
            AppText(.metadataRemovalCount, arguments: [String(model.removalCount)], style: .caption, color: .secondary)
            if let error = model.error { SettingsFootnote(message: error, tone: .danger) }
            ForEach(model.sources) { source in
                AppDisclosure(label: .verbatim(source.name)) {
                    if source.entries.isEmpty { AppText(.metadataNoFields, style: .caption, color: .secondary) }
                    ForEach(source.entries, id: \.self) { entry in
                        let isRemoved = model.selected.contains(entry.category)
                        AppMetadataEntry(name: entry.name, value: entry.value)
                            .opacity(isRemoved ? 1 : AppDimensions.Editor.unselectedOpacity)
                    }
                }
            }
            AppText(.metadataStructuralHint, style: .caption, color: .secondary)
        }
    }
    private static func label(_ category: MetadataCategory) -> L10nKey {
        switch category {
        case .descriptive: .metadataDescriptive
        case .location: .metadataLocation
        case .camera: .metadataCamera
        case .other: .metadataOther
        }
    }
}
