import SwiftUI

/// Finished images use the same readable destination rows as the action picker.
struct MobileResultSheet: View {
    let files: SharedFiles
    @Environment(\.dismiss) private var dismiss
    @Environment(Localizer.self) private var localizer
    @State private var model = MobileImageSaveViewModel()
    @State private var exporting = false
    @State private var exported = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        if let url = files.urls.first { AppFileThumbnail(url: url, size: 64) }
                        VStack(alignment: .leading, spacing: 5) {
                            // The title already says "Ready to save", so the file leads here.
                            AppText(verbatim: files.urls.first?.lastPathComponent ?? "", style: .headline)
                                .lineLimit(2).truncationMode(.middle)
                            AppText(.mobileBatchCount, arguments: [String(files.urls.count)],
                                    style: .caption, color: .secondary)
                        }
                    }
                    if !model.saved {
                        AppText(.mobileSavePrompt, style: .caption, color: .secondary)
                        VStack(spacing: 0) {
                            destination(.mobileSavePhotos, detail: .mobileSavePhotosDetail, symbol: "photo") {
                                Task { await model.save(files.urls) }
                            }
                            .accessibilityIdentifier("mobile.savePhotos")
                            Divider().padding(.leading, 58)
                            destination(.mobileSaveFiles, detail: .mobileSaveFilesDetail, symbol: "folder") {
                                exporting = true
                            }
                            .accessibilityIdentifier("mobile.saveFiles")
                        }
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
                        .disabled(model.isSaving)
                        if model.isSaving { ProgressView().frame(maxWidth: .infinity) }
                        if let error = model.error { SettingsFootnote(message: error, tone: .danger) }
                    } else {
                        Label(localizer.string(.mobilePhotosSaved), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.accent)
                        AppButton(key: .onboardingDone, variant: .primary) { dismiss() }
                    }
                }
                .padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .appScreenBackground()
            .mobileNavigationBar(.mobileResultReady)
            .toolbar {
                MobileCloseToolbar(isEnabled: !model.isSaving) { dismiss() }
            }
        }
        .sheet(isPresented: $exporting, onDismiss: exportDismissed) {
            MobileFileExporter(urls: files.urls) { saved in
                exported = saved
                exporting = false
            }.ignoresSafeArea()
        }
        .onChange(of: model.saved) { _, saved in if saved { AppFeedback.success() } }
        .interactiveDismissDisabled(model.isSaving)
        // Full height, so both destinations show without dragging on smaller and folded phones.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private func destination(
        _ title: L10nKey, detail: L10nKey, symbol: String, action: @escaping () -> Void
    ) -> some View {
        Button { AppFeedback.selection(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(AppColors.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.string(title)).font(.body.weight(.semibold))
                    Text(localizer.string(detail)).font(.caption).foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward").font(.caption).foregroundStyle(AppColors.textSecondary)
            }
            .foregroundStyle(AppColors.textPrimary).padding(16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func exportDismissed() {
        if exported { dismiss() }
    }
}
