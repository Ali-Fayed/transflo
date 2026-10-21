import SwiftUI

/// Circular progress with distinct success and failure end states.
struct AppProgressRing: View {
    @Environment(Localizer.self) private var localizer
    enum Status: Equatable {
        case progress(Double)
        case success
        case failure
    }

    let status: Status

    private static let progressStroke = StrokeStyle(lineWidth: AppDimensions.HUD.ringStroke, lineCap: .round)

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.divider, lineWidth: AppDimensions.HUD.ringStroke)
            switch status {
            case .progress(let fraction):
                Circle()
                    .trim(from: 0, to: max(0.02, min(fraction, 1)))
                    .stroke(AppColors.accent, style: Self.progressStroke)
                    .rotationEffect(.degrees(-90))
                    .animation(AppAnimations.progress, value: fraction)
            case .success:
                Circle().fill(AppColors.accent)
                AppIcon(symbol: .success, size: AppDimensions.IconSize.small).foregroundStyle(AppColors.accentContrast)
            case .failure:
                Circle().fill(AppColors.danger)
                AppIcon(symbol: .failure, size: AppDimensions.IconSize.small).foregroundStyle(AppColors.background)
            }
        }
        .frame(width: AppDimensions.HUD.ringSize, height: AppDimensions.HUD.ringSize)
        .accessibilityElement()
        .accessibilityLabel(localizer.string(.a11yProgress))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        switch status {
        case .progress(let fraction): min(max(fraction, 0), 1).formatted(.percent.precision(.fractionLength(0)))
        case .success: localizer.string(.jobDone)
        case .failure: localizer.string(.a11yFailed)
        }
    }
}
