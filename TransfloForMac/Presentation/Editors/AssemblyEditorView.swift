import SwiftUI
import TransfloDomain

struct AssemblyEditorView: View {
    @Bindable var model: AssemblyEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(.assemblyOrderHint, style: .caption, color: .secondary)
            AppReorderableList(items: model.order, onMove: model.move) { index in
                HStack(spacing: AppDimensions.Spacing.small) {
                    AppPreviewImage(data: model.facts.indices.contains(index) ? model.facts[index].thumbnail : nil)
                        .frame(width: AppDimensions.Editor.assemblyThumbnailSize,
                               height: AppDimensions.Editor.assemblyThumbnailSize)
                    VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                        AppText(verbatim: model.items[index].lastPathComponent)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if model.facts.indices.contains(index), let duration = model.facts[index].duration {
                            AppText(verbatim: TimeLabel.text(duration), style: .caption, color: .secondary)
                        }
                    }
                    Spacer(minLength: AppDimensions.Spacing.small)
                    AppMoveButtons(canMoveUp: model.order.first != index, canMoveDown: model.order.last != index) {
                        model.shift(index, by: $0)
                    }
                    AppIconButton(symbol: .remove, label: .editorRemove) { model.remove(index) }
                }
            }
            HStack {
                AppButton(key: .editorReverseOrder, variant: .tertiary) { model.reverse() }
                Spacer()
                AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
            }
            if model.isPDFExport { pdfControls } else {
                AppText(.assemblyOutput, arguments: [model.outputExtension, TimeLabel.text(model.totalDuration),
                                                     String(model.totalPages)], style: .caption, color: .secondary)
                AppText(.assemblyMediaHint, style: .caption, color: .secondary)
            }
        }
    }
    private var pdfControls: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(.assemblyPagePreview, style: .headline)
            AppPDFAssemblyPreview(data: model.firstFact.thumbnail, layout: model.assembly,
                               original: CGSize(width: max(1, model.firstFact.width ?? 1),
                                                height: max(1, model.firstFact.height ?? 1)))
            AppChipGroup(key: .assemblyPaper, selection: $model.paper, options: [
                .init(value: .original, label: .assemblyOriginal), .init(value: .aFour, label: .assemblyA4),
                .init(value: .letter, label: .assemblyLetter)
            ])
            if model.paper != .original {
                SettingsRow(label: .assemblyLandscape) { AppToggle(key: .assemblyLandscape, isOn: $model.landscape) }
            }
            AppDecimalNumberField(label: .assemblyMargin, unit: .unitPoints, value: $model.margin,
                                  identifier: "transflo.editor.pdf.margin")
            SettingsRow(label: .assemblyFill) { AppToggle(key: .assemblyFill, isOn: $model.fill) }
            AppText(.assemblyPDFHint, style: .caption, color: .secondary)
        }
    }
}
