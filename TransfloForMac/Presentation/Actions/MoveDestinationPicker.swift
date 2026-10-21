import AppKit
import TransfloDomain
import TransfloSystem

/// Move's destination menu at the drop point: recent folders that still exist, then
/// "Choose Folder…" (an open panel). Picking nothing schedules nothing.
final class MoveDestinationPicker: ActionPreparing {
    private let recents: any RecentFoldersRepository
    private let directories: any DirectoryChecking
    private let localizer: Localizer
    private var target: MenuActionTarget?
    private let folderAccess: SecurityScopedFolderAccess?

    init(
        recents: any RecentFoldersRepository,
        directories: any DirectoryChecking,
        localizer: Localizer,
        folderAccess: SecurityScopedFolderAccess? = nil
    ) {
        self.folderAccess = folderAccess
        self.recents = recents
        self.directories = directories
        self.localizer = localizer
    }

    func needsPreparation(_ action: ActionKind) -> Bool {
        action == .move
    }

    /// Recent destinations that are still folders, most recent first.
    func destinations() -> [URL] {
        recents.load().filter(directories.isDirectory(at:))
    }

    func prepare(
        _ action: ActionKind, items: [URL], near point: WheelPoint, onReady: @escaping (ToolSettings) -> Void
    ) {
        guard action == .move else { return }
        let target = MenuActionTarget { [weak self] folder in
            if let folder {
                onReady(.destination(folder))
            } else {
                self?.chooseFolder(onReady: onReady)
            }
        }
        self.target = target
        let menu = NSMenu(title: localizer.string(.moveMenuTitle))
        let header = NSMenuItem(title: localizer.string(.moveMenuTitle), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for folder in destinations() {
            let item = NSMenuItem(title: FileManager.default.displayName(atPath: folder.path),
                                  action: #selector(MenuActionTarget.pick(_:)), keyEquivalent: "")
            item.target = target
            item.representedObject = folder
            item.toolTip = folder.path
            item.image = NSWorkspace.shared.icon(forFile: folder.path)
            item.image?.size = CGSize(width: AppDimensions.IconSize.medium, height: AppDimensions.IconSize.medium)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let choose = NSMenuItem(title: localizer.string(.moveChooseFolder),
                                action: #selector(MenuActionTarget.pick(_:)), keyEquivalent: "")
        choose.target = target
        menu.addItem(choose)
        menu.popUp(positioning: nil, at: CGPoint(x: point.x, y: point.y), in: nil)
    }

    private func chooseFolder(onReady: @escaping (ToolSettings) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = localizer.string(.moveHere)
        panel.directoryURL = destinations().first
        NSApp.activate()
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        if let folderAccess, !folderAccess.rememberSelection(folder) { return }
        onReady(.destination(folder))
    }
}

/// Bridges menu item selection to a closure; a `nil` folder means "Choose Folder…".
private final class MenuActionTarget: NSObject {
    private let handler: (URL?) -> Void

    init(handler: @escaping (URL?) -> Void) {
        self.handler = handler
    }

    @objc func pick(_ sender: NSMenuItem) {
        handler(sender.representedObject as? URL)
    }
}
