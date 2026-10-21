import UIKit

/// Native lifecycle hooks; owns the composition root for the life of the process.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let container: MobileContainer

    override init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-transflo-mobile-defaults"), arguments.indices.contains(index + 1),
           let defaults = UserDefaults(suiteName: arguments[index + 1]) {
            if let marker = arguments.firstIndex(of: "-transflo-mobile-review-session"),
               arguments.indices.contains(marker + 1), let id = UUID(uuidString: arguments[marker + 1]) {
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("TransfloReview")
                    .appendingPathComponent(id.uuidString, isDirectory: true)
                container = MobileContainer(defaults: defaults, documents: root.appendingPathComponent("Files"),
                                            historyFile: root.appendingPathComponent("history.json"))
            } else {
                container = MobileContainer(defaults: defaults)
            }
        } else {
            container = MobileContainer()
        }
        #else
        container = MobileContainer()
        #endif
        super.init()
        MobileIntentRegistration.register(container.intents)
    }
}
