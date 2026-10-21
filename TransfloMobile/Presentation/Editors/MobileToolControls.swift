import SwiftUI
import TransfloDomain

/// Controls are deliberately scoped to settings the shared runners can execute on mobile.
struct MobileToolControls: View {
    @Bindable var model: MobileToolEditorModel
    @Environment(Localizer.self) private var localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch model.tool {
            case .compress:
                AppSegmentedPicker(key: .toolCompress, selection: $model.compression, options: [
                    .init(value: 0, label: .mobileBest), .init(value: 1, label: .mobileBalanced),
                    .init(value: 2, label: .mobileSmaller)
                ])
                if model.isVideo {
                    AppText(.mobileVideoCompressionDetail, style: .caption, color: .secondary)
                }
            case .resize:
                integer(.editorWidth, value: Binding(get: { model.width }, set: model.setWidth))
                integer(.editorHeight, value: Binding(get: { model.height }, set: model.setHeight))
                Toggle(localizer.string(.editorKeepProportions), isOn: $model.keepProportions)
                HStack {
                    AppButton(key: .editorHalfSize, variant: .secondary) {
                        model.width = max(1, model.originalWidth / 2)
                        model.height = max(1, model.originalHeight / 2)
                    }
                    AppButton(key: .editorOriginalSize, variant: .tertiary) {
                        model.width = model.originalWidth
                        model.height = model.originalHeight
                    }
                }
            case .crop:
                slider(.editorWidth, value: $model.cropWidth, range: 0.05...1)
                slider(.editorHeight, value: $model.cropHeight, range: 0.05...1)
                slider(.editorCropX, value: $model.cropX, range: 0...1)
                slider(.editorCropY, value: $model.cropY, range: 0...1)
            case .rotate:
                Stepper(value: $model.turns, in: 0...3) {
                    Text("\(localizer.string(.toolRotate)): \(model.turns * 90)°")
                }
                if !model.isPDF {
                    Toggle(localizer.string(.mobileFlipHorizontal), isOn: $model.flipHorizontal)
                    Toggle(localizer.string(.mobileFlipVertical), isOn: $model.flipVertical)
                }
            case .adjust:
                slider(.editorBrightness, value: $model.brightness, range: -0.5...0.5, resting: 0)
                slider(.editorContrast, value: $model.contrast, range: 0.5...1.5, resting: 1)
                slider(.editorSaturation, value: $model.saturation, range: 0...2, resting: 1)
                AppButton(key: .editorReset, variant: .tertiary) {
                    model.brightness = 0; model.contrast = 1; model.saturation = 1
                }
            case .addBackground: background
            case .collage:
                Stepper(localizer.string(.editorColumns) + ": \(model.columns)", value: $model.columns, in: 1...6)
                Stepper(localizer.string(.editorSpacing) + ": \(model.spacing)", value: $model.spacing, in: 0...80)
                background
            case .rename:
                TextField(localizer.string(.editorPattern), text: $model.pattern)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                integer(.editorStartAt, value: $model.start)
                AppText(.editorRenameHint, style: .caption, color: .secondary)
                ForEach(Array(zip(model.items, model.renamed).enumerated()), id: \.offset) { _, pair in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pair.0.lastPathComponent).foregroundStyle(AppColors.textSecondary)
                        Text(pair.1 + "." + pair.0.pathExtension).fontWeight(.medium)
                    }.font(.footnote)
                }
            case .extractPages, .reorganizePages: pages
            case .trim, .changeSpeed, .snapshot: MobileMediaControls(model: model)
            case .split where model.isMedia: MobileMediaControls(model: model)
            case .split:
                Stepper(localizer.string(.editorPagesPerFile) + ": \(model.pagesPerFile)",
                        value: $model.pagesPerFile, in: 1...max(1, model.pageCount - 1))
                AppText(.mobilePDFCount, arguments: [String(model.pageCount)], style: .caption, color: .secondary)
            case .editMetadata:
                TextField(localizer.string(.mobileMetadataTitle), text: $model.title).textFieldStyle(.roundedBorder)
                TextField(localizer.string(.mobileMetadataAuthor), text: $model.author).textFieldStyle(.roundedBorder)
                AppText(.editorMetadataHint, style: .caption, color: .secondary)
            case .removeMetadata: AppText(.mobileRemoveMetadataDetail, color: .secondary)
            case .removeBackground: AppText(.mobileRemoveBackgroundDetail, color: .secondary)
            case .readCode: AppText(.mobileReadCodeDetail, color: .secondary)
            case .merge, .imagesToPDF: orderedFiles
            default: EmptyView()
            }
        }
        .tint(AppColors.accent)
        .font(.body)
    }

    private var background: some View {
        ColorPicker(localizer.string(.editorBackground), selection: Binding(
            get: { Color(uiColor: UIColor(hex: model.colorHex)) },
            set: { model.colorHex = UIColor($0).rgbHex }
        ), supportsOpacity: false)
    }

    private var orderedFiles: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppText(.mobileCombineDetail, style: .caption, color: .secondary)
            ForEach(Array(model.items.enumerated()), id: \.offset) { index, url in
                HStack {
                    Text("\(index + 1)").foregroundStyle(AppColors.accent).monospacedDigit()
                    Text(url.lastPathComponent).lineLimit(2)
                }
            }
        }
    }

    private var pages: some View {
        VStack(spacing: 12) {
            AppText(.mobilePDFCount, arguments: [String(model.pageCount)], style: .caption, color: .secondary)
            if model.tool == .reorganizePages {
                AppButton(key: .editorReverseOrder, variant: .secondary) { model.pages.reverse() }
            }
            ForEach(Array(model.pages.enumerated()), id: \.element) { index, page in
                HStack {
                    Text(localizer.string(.editorPage, arguments: [String(page + 1)]))
                    Spacer()
                    if model.tool == .extractPages {
                        Toggle(localizer.string(.editorPage, arguments: [String(page + 1)]), isOn: Binding(
                            get: { model.selectedPages.contains(page) },
                            set: { selected in
                                if selected {
                                    model.selectedPages.insert(page)
                                } else { model.selectedPages.remove(page) }
                            }
                        )).labelsHidden()
                    } else {
                        Button { model.pages.swapAt(index, index - 1) } label: {
                            Image(systemName: AppSymbol.arrowUp.rawValue).frame(width: 36, height: 36)
                        }.disabled(index == 0).accessibilityLabel(localizer.string(.editorMovePageUp))
                        Button { model.pages.swapAt(index, index + 1) } label: {
                            Image(systemName: AppSymbol.arrowDown.rawValue).frame(width: 36, height: 36)
                        }.disabled(index == model.pages.count - 1)
                            .accessibilityLabel(localizer.string(.editorMovePageDown))
                    }
                }
                Divider()
            }
        }
    }

    private func integer(_ title: L10nKey, value: Binding<Int>) -> some View {
        HStack {
            AppText(title)
            Spacer()
            TextField(localizer.string(title), value: value, format: .number.grouping(.never))
                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder).frame(width: 110)
        }
    }

    private func slider(
        _ title: L10nKey, value: Binding<Double>, range: ClosedRange<Double>, resting: Double? = nil
    ) -> some View {
        MobileEditorSlider(title: title, value: value, range: range,
                  valueText: value.wrappedValue.formatted(.number.precision(.fractionLength(2))
                      .locale(localizer.locale)),
                  resting: resting)
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0xF5F4EF
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255, alpha: 1)
    }
    var rgbHex: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
