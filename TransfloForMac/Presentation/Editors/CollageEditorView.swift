import SwiftUI

/// Collage editor: grid preview, columns, gap and background.
struct CollageEditorView: View {
    @Bindable var model: CollageEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            if let composed = model.composed {
                AppPreviewImage(data: composed).frame(height: AppDimensions.Editor.previewHeight)
            } else {
                AppCollagePreview(thumbnails: model.orderedThumbnails, columns: model.columns,
                                  spacing: CGFloat(model.spacing) / Self.previewScale,
                                  backdrop: AppMarkupPalette.color(model.background))
            }
            if let error = model.renderError { SettingsFootnote(message: error, tone: .danger) }
            AppText(.collageOutputSize, arguments: [String(model.layoutSettings.outputWidth),
                String(model.layoutSettings.outputHeight)], style: .caption, color: .secondary)
            sourceOrder
            AppNumberField(label: .collageCellWidth, value: $model.cellWidth, range: 1...4096, unit: .unitPixels)
            AppNumberField(label: .collageCellHeight, value: $model.cellHeight, range: 1...4096, unit: .unitPixels)
            SettingsRow(label: .collageFill) { AppToggle(key: .collageFill, isOn: $model.fill) }
            AppNumberField(label: .editorColumns, value: $model.columns, range: model.columnRange)
            AppNumberField(label: .editorSpacing, value: $model.spacing, range: CollageEditorViewModel.spacingRange)
            AppChipGroup(key: .editorLayout, selection: layout, options: Self.layouts)
            AppText(.editorBackground, style: .headline)
            AppColorSwatches(selection: $model.background)
            AppCustomColorPicker(selection: $model.background)
            AppText(.editorGridSummary, arguments: [String(model.imageCount), String(model.rows)],
                    style: .caption, color: .secondary)
            AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
        }
        .task(id: model.layoutSettings) {
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            await model.renderPreview()
        }
    }

    private var sourceOrder: some View {
        AppReorderableList(items: model.order, onMove: model.move) { index in
            HStack {
                AppText(verbatim: model.items[index].lastPathComponent).fixedSize(horizontal: false, vertical: true)
                Spacer()
                AppMoveButtons(canMoveUp: model.order.first != index, canMoveDown: model.order.last != index) {
                    model.shift(index, by: $0)
                }
                AppIconButton(symbol: .remove, label: .editorRemove) { model.remove(index) }
            }
        }
    }

    private var layout: Binding<Int> {
        Binding(get: { model.layout }, set: { model.applyLayout($0) })
    }
    private static let layouts: [AppSegmentedPicker<Int>.Option] = [
        .init(value: 0, label: .editorGridLayout), .init(value: 1, label: .editorSingleRow),
        .init(value: 2, label: .editorSingleColumn)
    ]

    /// The preview is far smaller than the output, so the gap is drawn scaled down.
    private static let previewScale: CGFloat = 4
}
