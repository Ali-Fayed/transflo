import SwiftUI
import TransfloDomain

struct MobileRecentFiles: View {
    let model: MobileFilesViewModel
    @Environment(Localizer.self) private var localizer

    private var recent: [WorkspaceFile] {
        Array(model.folders.flatMap(\.files).sorted { $0.modified > $1.modified }.prefix(3))
    }

    var body: some View {
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                AppText(.mobileRecentFiles, style: .headline)
                VStack(spacing: 0) {
                    ForEach(recent) { file in
                        Button {
                            AppFeedback.selection()
                            model.convert([file.url])
                        } label: {
                            HStack(spacing: 14) {
                                AppFileThumbnail(url: file.url, size: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.name).font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppColors.textPrimary).lineLimit(1).truncationMode(.middle)
                                    Text(file.modified, style: .relative)
                                        .font(.caption).foregroundStyle(AppColors.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward").font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(16).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if file.id != recent.last?.id { Divider().padding(.leading, 74) }
                    }
                }
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .accessibilityIdentifier("mobile.recentFiles")
        }
    }
}
