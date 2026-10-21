import AppKit
import SwiftUI

struct CodeResultsView: View {
    @Bindable var model: CodeResultsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(.codesHint, style: .caption, color: .secondary)
            if let error = model.error { SettingsFootnote(message: error, tone: .danger) }
            ForEach(model.results.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
                    AppCheckbox(label: .verbatim(model.results[index]),
                                isOn: Binding(get: { model.selected.contains(index) },
                                              set: { _ in model.toggle(index) }))
                    HStack {
                        AppButton(key: .codesCopy, variant: .tertiary) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(model.results[index], forType: .string)
                        }
                        if let url = model.webURL(model.results[index]) {
                            AppButton(key: .codesOpen, variant: .tertiary) { NSWorkspace.shared.open(url) }
                        }
                    }
                    SettingsDivider()
                }
            }
            HStack {
                AppButton(key: .editorSelectAll, variant: .tertiary) { model.selectAll() }
                AppButton(key: .editorSelectNone, variant: .tertiary) { model.selectNone() }
            }
        }
    }
}
