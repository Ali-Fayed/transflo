import SwiftUI
import TransfloDomain

/// Familiar editing controls, a bounded source preview, and an explicit Apply before any processing.
struct MobileToolEditorView: View {
    @Bindable var model: MobileToolEditorModel
    let onCancel: () -> Void
    let onApply: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc").foregroundStyle(AppColors.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.items.first?.lastPathComponent ?? "").font(.headline).lineLimit(2)
                                AppText(.mobileBatchCount, arguments: [String(model.items.count)],
                                        style: .caption, color: .secondary)
                            }
                        }
                        let wide = proxy.size.width >= 820
                        let layout = wide
                            ? AnyLayout(HStackLayout(alignment: .top, spacing: 22))
                            : AnyLayout(VStackLayout(alignment: .leading, spacing: 22))
                        layout {
                            preview.frame(maxWidth: .infinity)
                            MobileToolControls(model: model)
                                .padding(20)
                                .frame(maxWidth: wide ? 340 : .infinity)
                                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 22))
                        }
                        if !model.loaded { ProgressView() }
                        if let message = model.message { SettingsFootnote(message: message, tone: .danger) }
                    }
                    .padding(20).frame(maxWidth: 1100).frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("mobile.editor.scroll")
            }
            .background(AppColors.background.ignoresSafeArea())
            .mobileNavigationBar(WheelPresentation.toolLabels[model.tool] ?? .wheelTools)
            .toolbar {
                MobileCloseToolbar(action: onCancel)
                ToolbarItem(placement: .confirmationAction) {
                    AppButton(key: .editorApply, variant: .primary, isEnabled: model.isValid, action: onApply)
                        .accessibilityIdentifier("mobile.editor.apply")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .task { await model.load() }
    }

    @ViewBuilder private var preview: some View {
        if model.isMedia {
            MobileMediaPreview(model: model)
        } else if let image = model.thumbnail {
            VStack(alignment: .leading, spacing: 10) {
                MobileToolImagePreview(image: image, model: model)
                    .frame(maxWidth: .infinity)
                    .frame(height: sizeClass == .regular ? 280 : 200)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18))
                AppText(.mobilePreviewSource, style: .caption, color: .secondary)
            }
        }
    }
}

private struct MobileToolImagePreview: View {
    let image: UIImage
    let model: MobileToolEditorModel

    var body: some View {
        Image(uiImage: displayedImage).resizable().scaledToFit().padding(14)
            .brightness(model.tool == .adjust ? model.brightness : 0)
            .contrast(model.tool == .adjust ? model.contrast : 1)
            .saturation(model.tool == .adjust ? model.saturation : 1)
            .overlay {
                if model.tool == .crop {
                    GeometryReader { proxy in
                        let aspect = image.size.width / max(1, image.size.height)
                        let width = min(proxy.size.width - 28, (proxy.size.height - 28) * aspect)
                        let height = width / aspect
                        Rectangle().stroke(AppColors.accent, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .frame(width: width * model.crop.width, height: height * model.crop.height)
                            .offset(x: (proxy.size.width - width) / 2 + width * model.crop.x,
                                    y: (proxy.size.height - height) / 2 + height * model.crop.y)
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var displayedImage: UIImage {
        guard model.tool == .rotate else { return image }
        let swaps = model.turns % 2 == 1
        let size = swaps ? CGSize(width: image.size.height, height: image.size.width) : image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            context.cgContext.scaleBy(x: model.flipHorizontal ? -1 : 1, y: model.flipVertical ? -1 : 1)
            context.cgContext.rotate(by: Double(model.turns) * .pi / 2)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
    }
}
