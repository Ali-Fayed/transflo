import QuickLook
import SwiftUI
import TransfloDomain

/// The Files tab: imports grouped by when they came in, each file with its thumbnail. Tap to
/// convert it; long-press for Quick Look, Share and Delete; Select for several at once.
struct MobileFilesView: View {
    @Environment(Localizer.self) private var localizer
    @Bindable var viewModel: MobileFilesViewModel
    /// Changes whenever a job finishes, so new results appear.
    let refreshKey: Int
    @State private var editMode: EditMode = .inactive

    var body: some View {
        Group {
            if viewModel.isEmpty {
                AppEmptyState(symbol: .folderTab, message: .mobileFilesEmpty)
            } else {
                list
            }
        }
        .appScreenBackground()
        .mobileNavigationBar(.mobileConvertedFiles)
        .toolbar { toolbar }
        .environment(\.editMode, $editMode)
        .quickLookPreview($viewModel.previewing)
        .task(id: refreshKey) { await viewModel.reload() }
        .refreshable { await viewModel.reload() }
        .accessibilityIdentifier("mobile.files")
    }

    private var list: some View {
        List(selection: $viewModel.selection) {
            if let message = viewModel.message {
                SettingsFootnote(message: message, tone: .danger).onTapGesture(perform: viewModel.dismissMessage)
            }
            ForEach(viewModel.folders) { folder in
                Section(folder.created.formatted(.dateTime.day().month().year().hour().minute()
                    .locale(localizer.locale))) {
                    ForEach(folder.files) { file in row(file).tag(file.url) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(_ file: WorkspaceFile) -> some View {
        HStack(spacing: AppDimensions.Spacing.medium) {
            AppFileThumbnail(url: file.url)
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                AppText(verbatim: file.name).lineLimit(2).truncationMode(.middle)
                AppText(verbatim: file.bytes.formatted(.byteCount(style: .file).locale(localizer.locale)),
                        style: .caption, color: .secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if editMode == .inactive { AppFeedback.selection(); viewModel.convert([file.url]) }
        }
        .contextMenu {
            AppMenuItem(key: .mobileConvert) { viewModel.convert([file.url]) }
            AppMenuItem(key: .mobileQuickLook) { viewModel.preview(file.url) }
            AppMenuItem(key: .jobShare) { viewModel.shareFiles([file.url]) }
            AppMenuItem(key: .editorRemove) { Task { await viewModel.delete([file.url]) } }
        }
        .swipeActions {
            AppSwipeAction(key: .editorRemove, symbol: .clearShelf, isDestructive: true) {
                Task { await viewModel.delete([file.url]) }
            }
            AppSwipeAction(key: .jobShare, symbol: .shareJob) { viewModel.shareFiles([file.url]) }
        }
        .accessibilityAction(named: localizer.string(.mobileQuickLook)) { viewModel.preview(file.url) }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if !viewModel.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        if editMode == .active, !viewModel.selection.isEmpty {
            let selected = Array(viewModel.selection)
            ToolbarItemGroup(placement: .bottomBar) {
                AppButton(key: .mobileConvert, variant: .primary) {
                    editMode = .inactive
                    viewModel.convert(selected)
                }
                Spacer()
                AppIconButton(symbol: .shareJob, label: .jobShare) { viewModel.shareFiles(selected) }
                AppIconButton(symbol: .clearShelf, label: .editorRemove) {
                    Task { await viewModel.delete(selected) }
                }
            }
        }
    }
}
