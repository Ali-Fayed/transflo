import SwiftUI
import TransfloDomain

/// A job from an earlier session, shown like this session's: its result's thumbnail, what ran, on
/// what and when, with Share while the result is still in the workspace.
struct MobileHistoryRow: View {
    @Environment(Localizer.self) private var localizer
    let entry: JobHistoryEntry
    let history: MobileHistoryViewModel

    var body: some View {
        let outputs = history.outputs(of: entry)
        MobileActivityRow(
            title: JobHistoryMapper.content(entry.title),
            detail: JobHistoryMapper.content(entry.files),
            status: .key(entry.failed ? .mobileActivityFailed : .mobileActivityDone),
            ring: entry.failed ? .failure : .success,
            preview: outputs.first,
            footnote: entry.finishedAt.formatted(.relative(presentation: .named).locale(localizer.locale)),
            onShare: outputs.isEmpty ? nil : { history.shareOutputs(of: entry) }
        )
    }
}
