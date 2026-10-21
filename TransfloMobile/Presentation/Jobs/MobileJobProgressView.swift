import SwiftUI

/// The running job in the middle of the screen, as on the Mac: the hub ringed by its progress,
/// ending in a check or a cross, with what is running and the time left. Hide moves it to the
/// bottom banner; tapping the disc opens Activity.
struct MobileJobProgressView: View {
    let banner: MobileJobBanner
    let jobs: JobListViewModel
    let onOpenJobs: () -> Void

    var body: some View {
        if !banner.isMinimized, let id = banner.jobID, let row = jobs.rows.first(where: { $0.id == id }) {
            VStack(spacing: AppDimensions.Spacing.medium) {
                AppResultDisc(status: row.ring)
                    .id(id)
                    .onTapGesture(perform: onOpenJobs)
                    .accessibilityAddTraits(.isButton)
                VStack(spacing: AppDimensions.Spacing.xSmall) {
                    AppText(row.operation, style: .headline)
                    AppText(row.files, style: .caption, color: .secondary).lineLimit(1).truncationMode(.middle)
                    AppText(row.timeLeft ?? row.status, style: .caption, color: row.isFailed ? .danger : .secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: AppDimensions.Spacing.small) {
                    if row.canCancel { AppButton(key: .jobCancel, variant: .secondary) { jobs.cancel(id) } }
                    if row.canReveal { AppButton(key: .jobShare, variant: .primary) { jobs.reveal(id) } }
                    AppButton(key: .mobileHideProgress, variant: .tertiary, action: banner.minimize)
                }
            }
            .padding(AppDimensions.Spacing.xLarge)
            .frame(maxWidth: AppDimensions.Mobile.progressCardWidth)
            .appGlass(.card, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
            .padding(AppDimensions.Spacing.large)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("mobile.jobProgress")
        }
    }
}
