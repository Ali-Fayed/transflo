#if DEBUG
import SwiftUI

/// A soft branded wallpaper for README screenshots: accent glows over the app background, so
/// glass surfaces have something calm to refract. Debug builds only.
struct AppScreenshotBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height)
            ZStack {
                AppColors.background
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: side * 0.6, height: side * 0.6)
                    .offset(x: -side * 0.22, y: -side * 0.18)
                    .blur(radius: side * 0.12)
                Circle()
                    .fill(AppColors.accentGlass)
                    .frame(width: side * 0.5, height: side * 0.5)
                    .offset(x: side * 0.25, y: side * 0.2)
                    .blur(radius: side * 0.14)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}
#endif
