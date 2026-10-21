import AppKit
import TransfloDomain

/// Hands files to the system AirDrop sheet.
public struct AirDropSharer: FileSharing {
    public init() {}

    public func share(_ urls: [URL]) async throws(JobError) {
        let started = await MainActor.run { () -> Bool in
            guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
                return false
            }
            NSApplication.shared.activate()
            service.perform(withItems: urls)
            return true
        }
        guard started else { throw .unsupported }
    }
}
