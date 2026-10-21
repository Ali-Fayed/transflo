import SwiftUI

/// A compact Home card: a tinted symbol beside a title and an optional live detail, the whole card tappable.
struct AppHomeTile: View {
    let symbol: String
    let title: AppTextContent
    var detail: AppTextContent?
    let action: () -> Void

    var body: some View {
        Button {
            AppFeedback.selection()
            action()
        } label: {
            HStack(spacing: AppDimensions.Spacing.medium) {
                Image(systemName: symbol)
                    .font(.system(size: AppDimensions.Mobile.tileGlyph, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: AppDimensions.Mobile.tileIcon, height: AppDimensions.Mobile.tileIcon)
                    .background(AppColors.accent.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: AppDimensions.Radius.medium))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    AppText(title, style: .headline).lineLimit(1).minimumScaleFactor(0.8)
                    if let detail { AppText(detail, style: .caption, color: .secondary).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: AppDimensions.Mobile.tileHeight, alignment: .leading)
            .padding(.horizontal, AppDimensions.Spacing.medium)
            .padding(.vertical, AppDimensions.Spacing.small)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppDimensions.Mobile.tileRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppDimensions.Mobile.tileRadius)
                    .strokeBorder(AppColors.divider, lineWidth: AppDimensions.Stroke.hairline)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppDimensions.Mobile.tileRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
