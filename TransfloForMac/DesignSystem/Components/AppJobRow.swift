import SwiftUI

/// A job in a list: progress ring, operation and files, status, and its actions.
struct AppJobRow: View {
    let ring: AppProgressRing.Status
    let title: AppTextContent
    let detail: AppTextContent
    let status: AppTextContent
    let isFailed: Bool
    var timeLeft: AppTextContent?
    let onCancel: (() -> Void)?
    let onReveal: (() -> Void)?
    var onUndo: (() -> Void)?

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.medium) {
            AppProgressRing(status: ring)
                .frame(width: AppDimensions.Jobs.ringSize, height: AppDimensions.Jobs.ringSize)
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                HStack(spacing: AppDimensions.Spacing.small) {
                    AppText(title, style: .headline)
                    AppText(detail, style: .caption, color: .secondary)
                        .truncationMode(.middle)
                }
                .lineLimit(1)
                HStack(spacing: AppDimensions.Spacing.small) {
                    AppText(status, style: .caption, color: isFailed ? .danger : .secondary)
                        .lineLimit(2)
                    if let timeLeft {
                        AppText(timeLeft, style: .caption, color: .secondary).monospacedDigit()
                    }
                }
            }
            Spacer(minLength: 0)
            if let onUndo {
                AppIconButton(symbol: .undoJob, label: .jobUndo, action: onUndo)
            }
            if let onReveal {
                AppIconButton(symbol: AppPlatform.revealSymbol, label: AppPlatform.revealLabel, action: onReveal)
            }
            if let onCancel {
                AppIconButton(symbol: .cancelJob, label: .jobCancel, action: onCancel)
            }
        }
        .padding(.vertical, AppDimensions.Spacing.small)
        .accessibilityElement(children: .contain)
    }
}
