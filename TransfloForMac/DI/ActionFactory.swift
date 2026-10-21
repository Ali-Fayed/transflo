import Foundation
import TransfloData
import TransfloDomain
import TransfloSystem

/// Builds the Actions-wheel runner (one performer per action) and Move's destination picker.
struct ActionFactory {
    let runner: any WheelJobRunning
    let preparer: MoveDestinationPicker

    init(
        localizer: Localizer,
        shelf: any FileShelving,
        inputPreferences: any InputPreferencesRepository,
        defaults: UserDefaults = .standard
    ) {
        let files = FileManagerExistenceChecker()
        let recents = UserDefaultsRecentFoldersRepository(defaults: defaults)
        let performers: [ActionKind: any FileActionPerforming] = [
            .airDrop: AirDropAction(sharer: AirDropSharer()),
            .float: FloatAction(shelf: shelf),
            .archive: ArchiveFilesAction(naming: NameOutputFileUseCase(checker: files)),
            .copy: CopyFilesAction(copier: PasteboardFileCopier()),
            .move: MoveAction(mover: FileMover(checker: files, directories: files), recents: recents),
            .copyPath: CopyPathAction(
                copier: PasteboardTextCopier(),
                modifiers: SystemModifierStateReader(),
                home: FileManager.default.homeDirectoryForCurrentUser
            ),
            .terminal: TerminalAction(opener: WorkspaceTerminalOpener(), directories: files) {
                inputPreferences.load().terminal
            }
        ]
        runner = ActionJobRunner(performers: performers, checker: files)
        preparer = MoveDestinationPicker(
            recents: recents, directories: files, localizer: localizer,
            folderAccess: EditionFactory.current.makeFolderAccess(localizer: localizer, defaults: defaults)
        )
    }
}
