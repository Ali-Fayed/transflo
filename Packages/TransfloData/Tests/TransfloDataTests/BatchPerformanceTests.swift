import Foundation
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Batch performance")
struct BatchPerformanceTests {
    private let catalog = MatrixConversionTests.catalog

    private func provider() throws -> CatalogWheelOptionsProvider {
        let engines: [any ToolEngine] = [
            ImageToolEngine(ffmpeg: MediaFixtures.ffmpeg, naming: MediaToolTests.naming, copier: SpyCopier()),
            MediaToolEngine(
                ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe, naming: MediaToolTests.naming
            ),
            PDFToolEngine(naming: MediaToolTests.naming),
            FileToolEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
        ]
        let tools = try BundledToolCatalogLoader().load().restricted(to: engines, formats: catalog.formats)
        return CatalogWheelOptionsProvider(catalog: catalog, tools: tools, fallback: PreviewWheelOptionsProvider(),
                                           engines: engines)
    }

    /// Median duration of `body` over a few runs, in milliseconds.
    private func milliseconds(_ body: () -> Void) -> Double {
        let samples = (0..<7).map { _ in
            let clock = ContinuousClock()
            let elapsed = clock.measure(body)
            return Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
        }
        return samples.sorted()[samples.count / 2]
    }

    /// One 60 Hz frame on a developer Mac. Shared, virtualized CI runners run this debug build a few
    /// times slower, so they get a looser bound that still catches a quadratic regression.
    private var budget: Double { ProcessInfo.processInfo.environment["CI"] == nil ? 16 : 100 }

    @Test("options for 1,000 dragged images resolve within one frame on every wheel")
    func thousandFiles() throws {
        let sut = try provider()
        let items = (0..<1000).map { URL(fileURLWithPath: "/tmp/photo \($0).\(["jpg", "png", "heic"][$0 % 3])") }
        for wheel in WheelKind.allCases {
            var options: [WheelOption] = []
            let time = milliseconds { options = sut.options(for: wheel, items: items) }
            #expect(time < budget, "\(wheel) took \(time) ms (budget \(budget) ms)")
            #expect(!options.isEmpty)
        }
    }
}
