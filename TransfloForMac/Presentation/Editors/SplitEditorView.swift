import SwiftUI

/// Split editor: number of equal parts for media, pages per file for PDFs.
struct SplitEditorView: View {
    @Bindable var model: SplitEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            if !model.isPDF { MediaAuditionView(url: model.item, previews: model.previews) }
            if model.isPDF {
                AppNumberField(label: .editorPagesPerFile, value: $model.pagesPerFile, range: model.pageRange)
            } else {
                AppChipGroup(key: .editorSplitMode, selection: $model.mode, options: [
                    .init(value: .equal, label: .editorEqualParts), .init(value: .custom, label: .editorCustomCuts)
                ])
                if model.mode == .equal {
                    AppNumberField(label: .editorParts, value: $model.parts, range: SplitEditorViewModel.partRange)
                } else {
                    AppDecimalNumberField(label: .editorCutAt, unit: .unitSeconds, value: $model.cutTime,
                                          identifier: "transflo.split.cut", precision: 3)
                    AppButton(key: .editorAddCut, variant: .tertiary, isEnabled: model.canAddCut) { model.addCut() }
                    ForEach(model.cuts, id: \.self) { cut in
                        HStack {
                            AppText(verbatim: TimeLabel.text(cut))
                            Spacer()
                            AppIconButton(symbol: .remove, label: .editorRemove) { model.removeCut(cut) }
                        }
                    }
                }
            }
            AppText(.editorOutputCount, arguments: [String(model.outputCount)], style: .caption, color: .secondary)
            ForEach(Array(model.segmentDurations.enumerated()), id: \.offset) { index, duration in
                AppText(.splitPartDuration, arguments: [String(index + 1), TimeLabel.text(duration)],
                        style: .caption, color: .secondary)
            }
            AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
        }
    }
}
