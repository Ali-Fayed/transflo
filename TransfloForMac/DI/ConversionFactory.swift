import Foundation
import os
import TransfloData
import TransfloDomain
import TransfloSystem

/// Builds the conversion engines and the catalog restricted to what they can run on this Mac.
struct ConversionFactory {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
        category: "Catalog"
    )

    let engines: [any ConversionEngine]
    let catalog: ConversionCatalog

    /// - Parameter includesIWork: Pages, Keynote and Numbers conversions (not in the sandboxed edition).
    init(
        loader: any ConversionCatalogLoading = BundledCatalogLoader(),
        bundle: Bundle = .main,
        includesIWork: Bool = true
    ) {
        let imageIO = ImageIOEngine()
        let ffmpeg = FFmpegEngine(binary: FFmpegEngine.bundledBinary(in: bundle))
        let naming = NameOutputFileUseCase(checker: FileManagerExistenceChecker())
        let helpers: [any ConversionEngine] = [
            imageIO, SVGEngine(rasterEngines: [imageIO, ffmpeg]), AVFoundationEngine(), ffmpeg,
            SubtitleEngine(), ArchiveEngine(), DocumentsEngine(), PDFKitEngine(naming: naming), SpreadsheetEngine()
        ]
        engines = includesIWork ? helpers + [IWorkEngine(helpers: helpers, naming: naming)] : helpers
        do {
            catalog = try loader.load().restricted(to: engines)
        } catch {
            Self.logger.fault("Conversion catalog unavailable: \(String(describing: error), privacy: .public)")
            catalog = ConversionCatalog(formats: [], paths: [])
        }
    }

    /// Files one batch converts at once: up to four, leaving cores for the rest of the Mac.
    static let parallelFiles = min(4, max(1, ProcessInfo.processInfo.activeProcessorCount / 2))

    func makeRunner() -> ConversionJobRunner {
        ConversionJobRunner(
            catalog: catalog,
            engines: engines,
            naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()),
            remover: FileManagerFileRemover(),
            maximumConcurrentItems: Self.parallelFiles
        )
    }
}
