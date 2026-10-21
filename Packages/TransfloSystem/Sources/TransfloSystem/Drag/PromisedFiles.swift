import AppKit
import UniformTypeIdentifiers

/// Drags from apps that don't have a file yet (Safari images, Photos, Mail attachments) carry file
/// promises instead of paths. The wheel shows options for placeholder names (their extensions come from
/// the promised types); on drop, the source app writes the real files into Downloads.
@MainActor
public enum PromisedFiles {
    /// Where placeholders point; nothing is ever written there.
    static let placeholderFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("transflo-promised", isDirectory: true)

    /// The dragged types `NSFilePromiseReceiver` reads, to register a drop view for.
    public static var draggedTypes: [NSPasteboard.PasteboardType] {
        NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
    }

    public static func receivers(on pasteboard: NSPasteboard) -> [NSFilePromiseReceiver] {
        pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
    }

    /// One placeholder per promised file, named by its type: `promised-1.jpeg`, `promised-2.heic`.
    public static func placeholders(on pasteboard: NSPasteboard) -> [URL] {
        receivers(on: pasteboard).enumerated().flatMap { index, receiver in
            receiver.fileTypes.enumerated().compactMap { typeIndex, identifier -> URL? in
                guard let fileExtension = UTType(identifier)?.preferredFilenameExtension else { return nil }
                return placeholderFolder.appendingPathComponent("promised-\(index + 1)-\(typeIndex + 1)")
                    .appendingPathExtension(fileExtension)
            }
        }
    }

    public static func isPlaceholder(_ url: URL) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL == placeholderFolder.standardizedFileURL
    }

    /// The folder promised files are written to, so results can be saved beside them.
    public static var destination: URL? {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    /// Asks the source apps to write their files into Downloads, then reports the files that arrived
    /// (an empty list when none did).
    public static func receive(
        _ receivers: [NSFilePromiseReceiver],
        completion: @escaping @MainActor ([URL]) -> Void
    ) {
        guard let destination, !receivers.isEmpty else {
            completion([])
            return
        }
        let collector = PromiseCollector(expected: receivers.count, completion: completion)
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        for (index, receiver) in receivers.enumerated() {
            receiver.receivePromisedFiles(atDestination: destination, options: [:],
                                          operationQueue: queue) { url, error in
                collector.add(error == nil ? url : nil, receiver: index)
            }
            collector.expect(receiver.fileNames, from: index)
        }
    }
}

// @unchecked: all mutable state is guarded by `lock`.
/// Gathers promised files as their writers finish, then calls back once on the main actor.
final class PromiseCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let receiverCount: Int
    private var names: [Int: [String]] = [:]
    private var deliveries: [Int: [URL?]] = [:]
    private var finished = false
    private let completion: @MainActor ([URL]) -> Void

    init(expected: Int, completion: @escaping @MainActor ([URL]) -> Void) {
        receiverCount = expected
        self.completion = completion
    }

    func expect(_ fileNames: [String], from receiver: Int) {
        update { names[receiver] = fileNames }
    }

    func add(_ url: URL?, receiver: Int) {
        update { deliveries[receiver, default: []].append(url) }
    }

    private func update(_ change: () -> Void) {
        let result: [URL]? = lock.withLock {
            guard !finished else { return nil }
            change()
            guard names.count == receiverCount, (0..<receiverCount).allSatisfy({
                deliveries[$0, default: []].count >= max(1, names[$0, default: []].count)
            }) else { return nil }
            finished = true
            let all = (0..<receiverCount).flatMap { index -> [URL?] in
                deliveries[index, default: []].sorted {
                    let first = names[index, default: []].firstIndex(of: $0?.lastPathComponent ?? "") ?? Int.max
                    let second = names[index, default: []].firstIndex(of: $1?.lastPathComponent ?? "") ?? Int.max
                    return first < second
                }
            }
            return all.contains(where: { $0 == nil }) ? [] : all.compactMap { $0 }
        }
        guard let result else { return }
        Task { @MainActor [completion] in completion(result) }
    }
}
