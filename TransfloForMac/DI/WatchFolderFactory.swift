import Foundation
import TransfloData
import TransfloDomain
import TransfloSystem

/// Builds the watch-folder service and its Settings section.
struct WatchFolderFactory {
    let coordinator: WatchFolderCoordinator
    private let repository: any WatchFolderRepository & RecipeRepository
    private let formats: [FormatDescriptor]
    private let picker: any FolderPicking

    init(
        edition: EditionFactory,
        conversion: ConversionFactory,
        tools: ToolFactory,
        repository: any WatchFolderRepository & RecipeRepository,
        jobs: JobCenter,
        localizer: Localizer,
        defaults: UserDefaults
    ) {
        self.repository = repository
        formats = conversion.catalog.formats
        // The App Store edition keeps access to a chosen folder as a security-scoped bookmark.
        picker = WatchFolderPicker(localizer: localizer,
                                   folderAccess: edition.makeFolderAccess(localizer: localizer, defaults: defaults))
        let resolve = ResolveWatchActionUseCase(
            options: edition.makeFittingOptions(conversion: conversion, tools: tools, recipes: repository),
            catalog: conversion.catalog, recipes: repository
        )
        coordinator = WatchFolderCoordinator(repository: repository, resolve: resolve, jobs: jobs,
                                             fingerprint: FileArtifactIdentity.fingerprint,
                                             isOwnOutput: OutputProvenance.shared.contains) { folder, handler in
            FolderWatcher(folder: folder) { handler($0) }
        }
    }

    func makeViewModel() -> WatchFoldersViewModel {
        let coordinator = coordinator
        return WatchFoldersViewModel(repository: repository, recipes: repository, formats: formats, picker: picker) {
            coordinator.reload()
        }
    }
}
