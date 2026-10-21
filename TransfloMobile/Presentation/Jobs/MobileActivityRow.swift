import SwiftUI

/// One job in Activity: a thumbnail of its result (or source) with a live progress ring, what ran,
/// on which file, and a status pill, plus Share and Cancel.
struct MobileActivityRow: View {
    @Environment(Localizer.self) private var localizer
    let title: AppTextContent
    let detail: AppTextContent
    let status: AppTextContent
    let ring: AppProgressRing.Status
    let preview: URL?
    var footnote: String?
    var onShare: (() -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.medium) {
            thumbnail
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                AppText(title, style: .headline).lineLimit(1)
                AppText(detail, style: .caption, color: .secondary).lineLimit(1).truncationMode(.middle)
                HStack(spacing: AppDimensions.Spacing.small) {
                    statusPill
                    if let footnote { AppText(verbatim: footnote, style: .caption, color: .secondary).lineLimit(1) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onShare {
                Button { AppFeedback.selection(); onShare() } label: {
                    Image(systemName: AppSymbol.shareJob.rawValue)
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(AppColors.accent)
                        .background(AppColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(localizer.string(.jobShare)))
            }
            if let onCancel { AppIconButton(symbol: .cancelJob, label: .jobCancel, action: onCancel) }
        }
        .padding(.vertical, AppDimensions.Spacing.small)
        .accessibilityElement(children: .contain)
    }

    private var thumbnail: some View {
        let side = AppDimensions.Mobile.activityThumbnail
        return ZStack(alignment: .bottomTrailing) {
            if let preview {
                AppFileThumbnail(url: preview, size: side)
            } else {
                RoundedRectangle(cornerRadius: AppDimensions.Radius.small).fill(AppColors.accent.opacity(0.12))
                    .overlay { AppIcon(symbol: .flowFile).foregroundStyle(AppColors.accent) }
                    .frame(width: side, height: side)
            }
            AppProgressRing(status: ring)
                .frame(width: AppDimensions.Mobile.historyRing * 0.75, height: AppDimensions.Mobile.historyRing * 0.75)
                .padding(AppDimensions.Spacing.xSmall / 2)
                .background(AppColors.background, in: Circle())
                .offset(x: AppDimensions.Spacing.small, y: AppDimensions.Spacing.small)
        }
        .padding(.trailing, AppDimensions.Spacing.small)
    }

    private var statusPill: some View {
        AppText(status, style: .caption, color: tone == .danger ? .danger : .primary)
            .lineLimit(1)
            .padding(.horizontal, AppDimensions.Spacing.small)
            .padding(.vertical, AppDimensions.Spacing.xSmall / 2)
            .background(pillColor.opacity(0.16), in: Capsule())
    }

    private enum Tone { case running, done, danger }

    private var tone: Tone {
        switch ring {
        case .progress: .running
        case .success: .done
        case .failure: .danger
        }
    }

    private var pillColor: Color {
        switch tone {
        case .running: AppColors.accent
        case .done: AppColors.accent
        case .danger: AppColors.danger
        }
    }
}
