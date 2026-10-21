import Foundation
import PDFKit
#if canImport(Quartz)
import Quartz
#endif
import TransfloDomain

/// PDF tools with PDFKit: Compress (Apple's Reduce File Size filter), Rotate, Merge (in drop
/// order), Split (a file every N pages) and Remove metadata (Info dictionary and XMP).
public struct PDFToolEngine: ToolEngine {
    static let tools: Set<ToolKind> = [
        .compress, .rotate, .merge, .split, .removeMetadata, .annotate, .redact, .reorganizePages, .extractPages,
        .editMetadata
    ]
    static let reduceFilter = URL(fileURLWithPath: "/System/Library/Filters/Reduce File Size.qfilter")
    #if canImport(Quartz)
    static var canReduce: Bool { FileManager.default.fileExists(atPath: reduceFilter.path) }
    #else
    static let canReduce = false
    #endif

    private let naming: ToolOutputNaming

    public init(naming: ToolOutputNaming) {
        self.naming = naming
    }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        guard Self.tools.contains(tool), formats.allSatisfy({ $0?.id.rawValue == "pdf" }) else { return false }
        switch tool {
        case .merge: return formats.count >= 2
        // Quartz's reduction filter exists only on the Mac.
        case .compress: return Self.canReduce
        default: return !formats.isEmpty
        }
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        try await BlockingWork.runCancellable { [self] isCancelled throws(JobError) -> [URL] in
            let items: [ToolItem]
            if case .assemble(let assembly) = request.settings {
                guard let ordered = assembly.ordered(request.items) else { throw .unsupported }
                items = ordered
            } else { items = request.items }
            try ToolPreflight.pdfs(items, settings: request.settings)
            if request.tool == .merge { return [try merge(items)] }
            if case let .splitPages(every) = request.settings { return try split(request.items, every: every) }
            var outputs: [URL] = []
            do throws(JobError) {
                for (index, item) in request.items.enumerated() {
                    if isCancelled() { throw .cancelled }
                    let output = try naming.destination(for: item.url, tool: request.tool)
                    try apply(request.tool, settings: request.settings, source: item.url, to: output)
                    outputs.append(output)
                    progress(Double(index + 1) / Double(request.items.count))
                }
            } catch {
                throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
            }
            return outputs
        }
    }

    private func apply(_ tool: ToolKind, settings: ToolSettings, source: URL, to output: URL) throws(JobError) {
        let document = try PDFKitEngine.open(source)
        if try applyMarkup(tool, settings: settings, document: document, output: output) { return }
        switch (tool, settings) {
        case (.compress, _):
            try compress(document, source: source, to: output)
        case let (.rotate, .rotate(turns, _, _)):
            try rotate(document, turns: turns)
            try write(document, to: output)
        case (.removeMetadata, let settings):
            if case .removeMetadata(let categories) = settings,
               categories != Set(MetadataCategory.allCases) {
                document.documentAttributes = (document.documentAttributes ?? [:]).filter {
                    !categories.contains(MetadataFiltering.category(String(describing: $0.key)))
                }
                try write(document, to: output)
            } else { try write(rebuilt(from: [document]), to: output) }
        case let (.reorganizePages, .pages(order)), let (.extractPages, .pages(order)):
            try write(try PDFPageEditing.pages(order, from: document), to: output)
        case let (.editMetadata, .metadata(values)):
            PDFPageEditing.setMetadata(values, on: document)
            try write(document, to: output)
        default:
            throw .unsupported
        }
    }

    private func applyMarkup(_ tool: ToolKind, settings: ToolSettings, document: PDFDocument, output: URL)
        throws(JobError) -> Bool {
        switch (tool, settings) {
        case let (.annotate, .annotate(annotations)):
            PDFPageEditing.annotate(document, with: annotations)
            try write(document, to: output)
        case let (.annotate, .pageAnnotations(pages)):
            for (index, marks) in pages {
                PDFPageEditing.annotate(document, with: marks, pageIndex: index)
            }
            try write(document, to: output)
        case let (.redact, .pageRedactions(pages)):
            for (index, boxes) in pages { try PDFPageEditing.redact(document, boxes: boxes, pageIndex: index) }
            try write(document, to: output)
        case let (.redact, .redact(boxes)):
            try PDFPageEditing.redact(document, boxes: boxes)
            try write(document, to: output)
        default: return false
        }
        return true
    }

    private func rotate(_ document: PDFDocument, turns: Int) throws(JobError) {
        for index in 0..<document.pageCount {
            if BlockingWork.isCancelled { throw .cancelled }
            guard let page = document.page(at: index) else { throw .failed }
            page.rotation = ((page.rotation + (turns % 4) * 90) % 360 + 360) % 360
        }
    }

    private func compress(_ document: PDFDocument, source: URL, to output: URL) throws(JobError) {
        try OutputFile.write(to: output) { staged throws(JobError) in
            try compressStaged(document, source: source, to: staged)
        }
    }

    private func compressStaged(_ document: PDFDocument, source: URL, to output: URL) throws(JobError) {
        #if canImport(Quartz)
        guard let filter = QuartzFilter(url: Self.reduceFilter) else { throw .unsupported }
        guard document.write(to: output, withOptions: [PDFDocumentWriteOption(rawValue: "QuartzFilter"): filter]) else {
            throw .failed
        }
        let before = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 0
        let after = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
        guard after > 0, before == 0 || after < before else {
            try? FileManager.default.removeItem(at: output)
            throw .nothingFound
        }
        #else
        throw .unsupported
        #endif
    }

    /// Each source becomes files of `every` pages, written one at a time so names number up.
    private func split(_ items: [ToolItem], every: Int) throws(JobError) -> [URL] {
        guard every > 0 else { throw .unsupported }
        var outputs: [URL] = []
        do throws(JobError) {
            for item in items {
                let document = try PDFKitEngine.open(item.url)
                guard document.pageCount > every else { throw .nothingFound }
                for start in stride(from: 0, to: document.pageCount, by: every) {
                    if BlockingWork.isCancelled { throw .cancelled }
                    let part = PDFDocument()
                    for index in start..<min(start + every, document.pageCount) {
                        guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
                        part.insert(page, at: part.pageCount)
                    }
                    let output = try naming.destination(for: item.url, tool: .split)
                    try write(part, to: output)
                    outputs.append(output)
                }
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        return outputs
    }

    private func merge(_ items: [ToolItem]) throws(JobError) -> URL {
        guard let first = items.first else { throw .failed }
        let documents = try items.map { item throws(JobError) in
            if BlockingWork.isCancelled { throw .cancelled }
            return try PDFKitEngine.open(item.url)
        }
        let output = try naming.destination(for: first.url, tool: .merge)
        try write(rebuilt(from: documents), to: output)
        return output
    }

    /// A fresh document holding copies of every page: no document-level Info or XMP carries over.
    private func rebuilt(from documents: [PDFDocument]) throws(JobError) -> PDFDocument {
        guard documents.reduce(0, { $0 + $1.pageCount }) <= 2_000 else { throw .unsupported }
        let result = PDFDocument()
        for document in documents {
            for index in 0..<document.pageCount {
                if BlockingWork.isCancelled { throw .cancelled }
                guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
                result.insert(page, at: result.pageCount)
            }
        }
        result.documentAttributes = [:]
        return result
    }

    private func write(_ document: PDFDocument, to url: URL) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in
            guard document.write(to: staged) else { throw .destinationUnavailable }
        }
    }
}
