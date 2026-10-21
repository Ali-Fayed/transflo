import SwiftUI

/// Shows PNG/JPEG data scaled to fit, or a quiet placeholder while it loads. `backdrop` shows
/// through transparent pixels (the surface color by default).
struct AppPreviewImage: View {
    let data: Data?
    var backdrop = AppColors.surface

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppDimensions.Radius.medium).fill(backdrop)
            if let data, let image = AppPlatform.image(data: data) {
                image
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }
}
