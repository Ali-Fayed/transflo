import Foundation
import TransfloDomain

/// A private scratch folder for one conversion, removed by `remove()`.
struct TemporaryWorkspace {
    let url: URL

    init(parent: URL? = nil) throws(JobError) {
        url = (parent ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent(".transflo-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw parent == nil ? .failed : .destinationUnavailable
        }
    }

    func subfolder(_ name: String) throws(JobError) -> URL {
        let folder = url.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw .failed
        }
        return folder
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
