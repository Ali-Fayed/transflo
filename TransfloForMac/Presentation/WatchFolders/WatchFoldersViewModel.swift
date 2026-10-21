import Foundation
import Observation
import TransfloDomain

/// Settings › Recipes › Watch Folders: which folders are watched and what happens to new files there.
/// Every change is saved and applied to the running watchers at once.
@Observable
final class WatchFoldersViewModel {
    private(set) var folders: [WatchFolder]
    @ObservationIgnored private let repository: any WatchFolderRepository
    @ObservationIgnored private let recipes: any RecipeRepository
    @ObservationIgnored private let picker: any FolderPicking
    @ObservationIgnored private let onChange: () -> Void
    /// Formats a Convert action can target.
    let formats: [FormatDescriptor]

    init(
        repository: any WatchFolderRepository,
        recipes: any RecipeRepository,
        formats: [FormatDescriptor],
        picker: any FolderPicking,
        onChange: @escaping () -> Void
    ) {
        self.repository = repository
        self.recipes = recipes
        self.formats = formats
        self.picker = picker
        self.onChange = onChange
        folders = repository.loadWatchFolders()
    }

    /// Choosing a folder adds it, converting new files to WebP to begin with (images are the usual case).
    func addFolder() async {
        guard let folder = await picker.pickFolder() else { return }
        guard !folders.contains(where: { $0.folder.standardizedFileURL == folder.standardizedFileURL }) else {
            return
        }
        let format = formats.first { $0.id.rawValue == "webp" } ?? formats.first
        let action = format.map { WatchAction.convert(formatID: $0.id.rawValue) } ?? .compress
        folders.append(WatchFolder(folder: folder, action: action))
        save()
    }

    func remove(_ id: WatchFolder.ID) {
        folders.removeAll { $0.id == id }
        save()
    }

    func setEnabled(_ id: WatchFolder.ID, _ enabled: Bool) {
        update(id) { $0.isEnabled = enabled }
    }

    func setAction(_ id: WatchFolder.ID, _ action: WatchAction) {
        update(id) { $0.action = action }
    }

    /// Every action a folder can run: Compress, each recipe, then Convert to each format.
    var actions: [(action: WatchAction, label: AppTextContent)] {
        [(WatchAction.compress, AppTextContent.key(.watchActionCompress))]
            + recipes.loadRecipes().filter(\.isValid).map { (.recipe($0.id), .verbatim($0.name)) }
            + formats.map { (.convert(formatID: $0.id.rawValue), .formatted(.recipeStepConvert, [$0.displayName])) }
    }

    private func update(_ id: WatchFolder.ID, _ change: (inout WatchFolder) -> Void) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        change(&folders[index])
        save()
    }

    private func save() {
        repository.saveWatchFolders(folders)
        onChange()
    }
}
