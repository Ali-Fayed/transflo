import SwiftUI
import TransfloDomain

/// Uses the exact placement rules of PDF export, including margin clipping in Fill mode.
struct AppPDFAssemblyPreview: View {
    @Environment(Localizer.self) private var localizer
    let data: Data?
    let layout: AssemblySettings
    let original: CGSize

    var body: some View {
        let page = layout.pageSize(original: original)
        GeometryReader { geometry in
            let scale = min(geometry.size.width / page.width, geometry.size.height / page.height)
            let size = CGSize(width: page.width * scale, height: page.height * scale)
            let frame = layout.imageFrame(image: original, page: page)
            let marginX = min(max(0, layout.margin), page.width / 3) * scale
            let marginY = min(max(0, layout.margin), page.height / 3) * scale
            ZStack(alignment: .topLeading) {
                AppColors.paper
                if let data, let image = AppPlatform.image(data: data) {
                    ZStack(alignment: .topLeading) {
                        image.resizable()
                            .frame(width: frame.width * scale, height: frame.height * scale)
                            .offset(x: frame.minX * scale, y: frame.minY * scale)
                    }
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .mask(alignment: .topLeading) {
                        Rectangle().frame(width: max(1, size.width - marginX * 2),
                                          height: max(1, size.height - marginY * 2))
                            .offset(x: marginX, y: marginY)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: AppDimensions.Editor.assemblyPreviewHeight)
        .accessibilityLabel(localizer.string(.a11yPDFPreview))
    }
}
