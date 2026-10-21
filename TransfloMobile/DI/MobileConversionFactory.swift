import Foundation
import os
import TransfloData
import TransfloDomain

/// Builds the conversion engines that run on iPhone and iPad (ImageIO, AVFoundation, subtitles,
/// PDFKit, text documents) and the catalog restricted to them.
struct MobileConversionFactory {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
                                       category: "Catalog")

    let engines: [any ConversionEngine]
    let catalog: ConversionCatalog

    init(loader: any ConversionCatalogLoading = BundledCatalogLoader()) {
        let naming = NameOutputFileUseCase(checker: FileManagerExistenceChecker())
        engines = [ImageIOEngine(), AVFoundationEngine(), SubtitleEngine(), PDFKitEngine(naming: naming),
                   TextDocumentEngine()]
        do {
            catalog = try loader.load().restricted(to: engines)
        } catch {
            Self.logger.fault("Conversion catalog unavailable: \(String(describing: error), privacy: .public)")
            catalog = ConversionCatalog(formats: [], paths: [])
        }
    }

    /// Files one batch converts at once: two, which keeps a phone cool and responsive.
    static let parallelFiles = 2

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
