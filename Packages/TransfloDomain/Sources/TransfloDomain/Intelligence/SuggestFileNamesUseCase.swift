import Foundation

/// Smart Rename's suggestions: what an image shows (and any text in it), written up as a short
/// descriptive file name by the on-device language model. Every name is sanitized and unique within
/// the batch; a file the model can't name keeps its current name.
public struct SuggestFileNamesUseCase: Sendable {
    private let understanding: any ImageUnderstanding
    private let writer: any TextWriting
    private let created: @Sendable (URL) -> Date?

    public init(
        understanding: any ImageUnderstanding,
        writer: any TextWriting,
        created: @escaping @Sendable (URL) -> Date? = Self.creationDate(of:)
    ) {
        self.understanding = understanding
        self.writer = writer
        self.created = created
    }

    /// Whether names can be suggested on this Mac (Apple Intelligence is on and ready).
    public var isAvailable: Bool { writer.isAvailable }

    /// One name per item, in order, without extensions.
    public func execute(for items: [URL]) async throws(JobError) -> [String] {
        guard isAvailable else { throw .unsupported }
        var names: [String] = []
        for item in items {
            if Task.isCancelled { throw .cancelled }
            let current = item.deletingPathExtension().lastPathComponent
            let suggestion = try await suggestion(for: item)
            guard !suggestion.isEmpty else {
                names.append(current)
                continue
            }
            let siblings = zip(items.prefix(names.count), names).compactMap { previous, name in
                previous.deletingLastPathComponent().standardizedFileURL == item.deletingLastPathComponent()
                    .standardizedFileURL ? name : nil
            }
            names.append(Self.unique(suggestion, among: siblings))
        }
        return names
    }

    private func suggestion(for item: URL) async throws(JobError) -> String {
        let labels = try await understanding.labels(for: item)
        let text = try await understanding.text(in: item)
        guard !labels.isEmpty || !text.isEmpty else { return "" }
        return FileNameSanitizer.sanitize(try await writer.fileName(labels: labels, text: text, created: created(item)))
    }

    /// `name`, or `name-2`, `name-3`… when an earlier file in the batch already took it.
    static func unique(_ name: String, among taken: [String]) -> String {
        let used = Set(taken.map { $0.lowercased() })
        guard used.contains(name.lowercased()) else { return name }
        var index = 2
        while used.contains("\(name)-\(index)".lowercased()) { index += 1 }
        return "\(name)-\(index)"
    }

    public static func creationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }
}
