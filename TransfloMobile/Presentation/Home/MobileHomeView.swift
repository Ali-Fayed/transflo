import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Home: drop files (Split View, Slide Over, or from another app on iPhone) or pick them from Files
/// or Photos; the action picker then opens for them.
struct MobileHomeView: View {
    @Environment(Localizer.self) private var localizer
    @Environment(\.horizontalSizeClass) private var sizeClass
    let viewModel: MobileHomeViewModel
    var files: MobileFilesViewModel?
    var refreshKey = 0
    var shortcuts: MobileHomeShortcuts?
    @State private var isTargeted = false
    @State private var isPickingFiles = false
    @State private var isPickingPhotos = false
    @State private var choosingMediaSource = false
    @State private var mediaKind = MobileInputCatalog.Kind.image
    @State private var photosFilter = PHPickerFilter.any(of: [.images, .videos])
    @State private var inputTypes: [UTType] = [.png]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    AppFlowMark(size: 48, animated: false)
                    VStack(alignment: .leading, spacing: 4) {
                        AppText(.mobileWorkspaceTitle, style: .title)
                        AppText(.mobileWorkspaceDetail, style: .caption, color: .secondary)
                    }
                }
                AppText(.mobileSelectType, style: .headline)
                inputList
                if let shortcuts { shortcutCards(shortcuts) }
                if let files { MobileRecentFiles(model: files) }
                if viewModel.state.isImporting { ProgressView().tint(AppColors.accent) }
                if let message = viewModel.state.message {
                    SettingsFootnote(message: message, tone: .danger)
                        .onTapGesture(perform: viewModel.dismissMessage)
                        .accessibilityIdentifier("mobile.importError")
                }
            }
            .padding(20)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .background {
            AppPhotosPickerButton(label: .mobileChoosePhotos, onPicked: receiveStaged,
                                  onFailure: viewModel.receiveFailed,
                                  onPresentationChange: { viewModel.isSelectingInput = $0 },
                                  isPresented: $isPickingPhotos, showsButton: false, filter: photosFilter)
        }
        .onDrop(of: [.item], isTargeted: $isTargeted) { providers in
            Task { receiveStaged(await ItemProviderFileLoader.files(from: providers)) }
            return true
        }
        .background {
            // A fresh importer per type set: SwiftUI can otherwise reuse the previous picker's filter.
            Color.clear
                .fileImporter(isPresented: $isPickingFiles, allowedContentTypes: inputTypes,
                              allowsMultipleSelection: true) {
                    switch $0 {
                    case .success(let urls): receive(urls)
                    case .failure(let error): viewModel.pickerFailed(error)
                    }
                }
                .id(inputTypes.map(\.identifier))
        }
        .confirmationDialog(localizer.string(mediaKind == .video ? .mobileVideoSource : .mobileImageSource),
                            isPresented: $choosingMediaSource,
                            titleVisibility: .visible) {
            Button(localizer.string(.mobileFilesTitle)) { AppFeedback.selection(); presentFiles() }
            Button(localizer.string(.mobilePhotoLibrary)) {
                AppFeedback.selection()
                presentPhotos(mediaKind == .video ? .videos : .images)
            }
        }
        .task(id: refreshKey) { await files?.reload() }
        .onChange(of: viewModel.state.isImporting) { _, importing in
            if !importing { Task { await files?.reload() } }
        }
        .onChange(of: isPickingFiles) { _, shown in viewModel.isSelectingInput = shown }
        .mobileNavigationBar(.flowHomeTab)
        .accessibilityIdentifier("mobile.home")
    }

    private var inputList: some View {
        AppPairedGrid(items: (viewModel.inputs?.options ?? []).filter { $0.kind != .subtitle }) { input in
            AppHomeTile(symbol: input.kind.symbol, title: .key(input.kind.title)) {
                inputTypes = input.contentTypes
                // Photos and videos can come from the library as well as Files.
                if [.image, .video].contains(input.kind) {
                    mediaKind = input.kind
                    choosingMediaSource = true
                } else { presentFiles() }
            }
            .accessibilityIdentifier("mobile.select.\(input.kind.rawValue)")
        }
        .disabled(viewModel.state.isImporting)
    }

    private func shortcutCards(_ shortcuts: MobileHomeShortcuts) -> some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(.mobileShortcuts, style: .headline)
            AppPairedGrid(items: MobileHomeShortcut.allCases) { shortcut in
                switch shortcut {
                case .photos:
                    AppHomeTile(symbol: "photo.on.rectangle.angled", title: .key(.mobilePhotoLibrary),
                                detail: .key(.mobileShortcutPhotosDetail)) {
                        presentPhotos(.any(of: [.images, .videos]))
                    }
                case .files:
                    AppHomeTile(symbol: AppSymbol.folderTab.rawValue, title: .key(.mobileConvertedFiles),
                                detail: .formatted(.mobileShortcutFileCount, [String(shortcuts.fileCount)]),
                                action: shortcuts.showFiles)
                case .activity:
                    AppHomeTile(symbol: AppSymbol.activityTab.rawValue, title: .key(.mobileActivityTitle),
                                detail: shortcuts.runningJobs > 0
                                    ? .formatted(.mobileShortcutRunning, [String(shortcuts.runningJobs)])
                                    : .key(.mobileShortcutIdle),
                                action: shortcuts.showActivity)
                case .recipes:
                    AppHomeTile(symbol: AppSymbol.recipe.rawValue, title: .key(.settingsRecipes),
                                detail: .formatted(.mobileShortcutRecipeCount, [String(shortcuts.recipeCount)]),
                                action: shortcuts.showRecipes)
                }
            }
        }
        .accessibilityIdentifier("mobile.shortcuts")
    }

    /// Opens the library on the next turn, once it has the chosen filter.
    private func presentPhotos(_ filter: PHPickerFilter) {
        photosFilter = filter
        DispatchQueue.main.async { isPickingPhotos = true }
    }

    /// Opens Files on the next turn, once the importer for the chosen types exists.
    private func presentFiles() {
        DispatchQueue.main.async { isPickingFiles = true }
    }

    private func receive(_ urls: [URL]) {
        guard !urls.isEmpty else { return viewModel.receiveFailed() }
        Task { await viewModel.receive(urls) }
    }

    private func receiveStaged(_ urls: [URL]) {
        guard !urls.isEmpty else { return viewModel.receiveFailed() }
        Task {
            defer { ItemProviderFileLoader.discard(urls) }
            await viewModel.receive(urls)
        }
    }
}

#if DEBUG
#Preview {
    MobilePreviews.home
}
#endif
