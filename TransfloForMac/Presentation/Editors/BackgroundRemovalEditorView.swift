import SwiftUI

struct BackgroundRemovalEditorView: View {
    @Bindable var model: BackgroundRemovalEditorViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppPreviewImage(data: model.showOriginal ? model.original : model.result)
                .frame(height: AppDimensions.Editor.previewHeight)
            SettingsRow(label: .editorShowOriginal) { AppToggle(key: .editorShowOriginal, isOn: $model.showOriginal) }
            if let error = model.error { SettingsFootnote(message: error, tone: .danger) }
            if model.rendering { AppSpinner() }
            if model.subjects.count > 1 {
                AppNumberField(label: .backgroundSubject, value: Binding(
                    get: { model.options.subject ?? 0 },
                    set: { model.options.subject = $0 == 0 ? nil : $0 }), range: 0...(model.subjects.max() ?? 1))
                AppText(.backgroundSubjectHint, style: .caption, color: .secondary)
            }
            AppSlider(label: .backgroundFeather, value: $model.options.feather, range: 0...0.02,
                      valueText: String(format: "%.1f%%", model.options.feather * 100))
            SettingsRow(label: .backgroundSolid) { AppToggle(key: .backgroundSolid, isOn: $model.solidBackground) }
            if model.solidBackground {
                AppColorSwatches(selection: $model.color)
                AppCustomColorPicker(selection: $model.color)
            }
            AppText(.backgroundPNGHint, style: .caption, color: .secondary)
            HStack {
                AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
                Spacer()
                AppButton(key: .backgroundRefresh, variant: .tertiary, isEnabled: !model.rendering) {
                    Task { await model.refresh() }
                }
            }
        }
        .task(id: model.requested) {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await model.refresh()
        }
    }
}
