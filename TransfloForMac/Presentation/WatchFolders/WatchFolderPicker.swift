import AppKit
import TransfloSystem

/// Chooses a folder to watch with the standard open panel. In the App Store edition the choice is
/// remembered as a security-scoped bookmark, so watching resumes after relaunch.
struct WatchFolderPicker: FolderPicking {
    let localizer: Localizer
    let folderAccess: SecurityScopedFolderAccess?

    func pickFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = localizer.string(.watchChoose)
        panel.message = localizer.string(.watchChooseMessage)
        NSApp.activate()
        let response = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let folder = panel.url else { return nil }
        if let folderAccess, !folderAccess.rememberSelection(folder) { return nil }
        return folder
    }
}
