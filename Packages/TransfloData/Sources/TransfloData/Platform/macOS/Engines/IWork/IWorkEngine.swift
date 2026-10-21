#if os(macOS)
import Foundation
import TransfloDomain

/// Conversions that need Apple's own apps: Pages (`.pages` in and out), Keynote (PPT/PPTX
/// to PDF, images and PPTX) and Numbers (XLS in). Formats an app cannot open or write directly
/// are chained through Transflo's other engines via a temporary DOCX or XLSX.
public struct IWorkEngine: ConversionEngine {
    public let id = EngineIDs.iWork
    static let docx = FormatDescriptor(
        id: FormatID("docx"), displayName: "DOCX", extensions: ["docx"], family: .document
    )
    /// Sources Pages opens itself; others become DOCX first.
    static let pagesNativeInputs: Set<String> = ["docx", "txt", "rtf", "rtfd", "pages"]

    private let helpers: [any ConversionEngine]
    private let placement: OutputPlacement
    private let isInstalled: @Sendable (IWorkApp) -> Bool

    /// - Parameter helpers: Engines used for the non-iWork leg of chained conversions.
    public init(helpers: [any ConversionEngine], naming: NameOutputFileUseCase) {
        self.init(helpers: helpers, naming: naming) { $0.isInstalled }
    }

    /// - Parameter isInstalled: Replaces the Launch Services check (tests).
    init(
        helpers: [any ConversionEngine],
        naming: NameOutputFileUseCase,
        isInstalled: @escaping @Sendable (IWorkApp) -> Bool
    ) {
        self.helpers = helpers
        self.placement = OutputPlacement(naming: naming)
        self.isInstalled = isInstalled
    }

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        guard let plan = IWorkPlan.make(source: source.id.rawValue, target: target.id.rawValue) else { return false }
        guard isInstalled(plan.app) else { return false }
        return plan.before.map { helper(from: source, to: $0) != nil } ?? true
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard FileManager.default.fileExists(atPath: request.source.path) else { throw .sourceMissing }
        let source = request.sourceFormat.id.rawValue
        guard let plan = IWorkPlan.make(source: source, target: request.targetFormat.id.rawValue) else {
            throw .unsupported
        }
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        var input = request.source
        if let before = plan.before {
            input = try await runHelper(request.source, from: request.sourceFormat, to: before, in: workspace)
        }
        progress(0.3)
        let exported = workspace.url.appendingPathComponent("export").appendingPathExtension(plan.exportExtension)
        try await IWorkAutomation.export(input, with: plan.app, kind: plan.exportKind, to: exported)
        progress(0.8)
        if plan.after != nil {
            let source = FormatDescriptor(
                id: FormatID(plan.exportKind), displayName: plan.exportKind, extensions: [plan.exportExtension],
                family: request.sourceFormat.family
            )
            guard let engine = helper(from: source, to: request.targetFormat) else { throw .unsupported }
            let chained = ConversionRequest(
                source: exported,
                destination: request.destination,
                sourceFormat: source,
                targetFormat: request.targetFormat
            )
            return try await engine.convert(chained) { progress(0.8 + $0 * 0.2) }
        }
        return try placement.place(exportedFiles(at: exported), for: request)
    }

    private func runHelper(
        _ source: URL, from format: FormatDescriptor, to target: FormatDescriptor, in workspace: TemporaryWorkspace
    ) async throws(JobError) -> URL {
        guard let engine = helper(from: format, to: target) else { throw .unsupported }
        let output = workspace.url.appendingPathComponent("intermediate").appendingPathExtension(target.outputExtension)
        let request = ConversionRequest(source: source, destination: output, sourceFormat: format, targetFormat: target)
        return try await engine.convert(request) { _ in }.first ?? output
    }

    private func helper(from source: FormatDescriptor, to target: FormatDescriptor) -> (any ConversionEngine)? {
        helpers.first { $0.canConvert(from: source, to: target) }
    }

    /// Keynote writes slide images into a folder; other exports are a single file.
    private func exportedFiles(at url: URL) -> [URL] {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) else { return [] }
        guard isFolder.boolValue else { return [url] }
        return (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }
}
#endif
