import SwiftUI

/// The minimized running or just-finished job, pinned to the bottom; tapping it opens Activity.
struct MobileJobBannerView: View {
    let banner: MobileJobBanner
    let jobs: JobListViewModel
    let onOpenJobs: () -> Void

    var body: some View {
        if banner.isMinimized, let id = banner.jobID, let row = jobs.rows.first(where: { $0.id == id }) {
            AppJobRow(
                ring: row.ring, title: row.operation, detail: row.files, status: row.status,
                isFailed: row.isFailed, timeLeft: row.timeLeft,
                onCancel: row.canCancel ? { jobs.cancel(row.id) } : nil,
                onReveal: row.canReveal ? { jobs.reveal(row.id) } : nil
            )
            .padding(.horizontal, AppDimensions.Spacing.large)
            .padding(.vertical, AppDimensions.Spacing.small)
            .appGlass(.card, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpenJobs)
            .padding(AppDimensions.Spacing.large)
            .frame(maxWidth: AppDimensions.Mobile.readableWidth)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("mobile.jobBanner")
        }
    }
}
