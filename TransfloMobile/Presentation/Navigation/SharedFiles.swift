import Foundation

/// Files offered in the share sheet.
struct SharedFiles: Identifiable, Equatable {
    let id = UUID()
    let urls: [URL]
}
