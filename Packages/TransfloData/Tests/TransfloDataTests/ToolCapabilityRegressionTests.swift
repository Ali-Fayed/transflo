import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Tool capability regressions")
struct ToolCapabilityRegressionTests {
    @Test("PNG background removal works without a WebP output encoder")
    func backgroundRemovalDoesNotRequireSourceEncoder() {
        let engine = ImageToolEngine(ffmpeg: nil, naming: MediaToolTests.naming, copier: SpyCopier())
        let webp = MatrixConversionTests.catalog.format(FormatID("webp"))
        #expect(engine.canRun(.removeBackground, on: [webp]))
        #expect(!engine.canRun(.adjust, on: [webp]))
        #expect(!engine.canRun(.removeBackground, on: [nil]))
        #expect(!engine.canRun(.removeBackground, on: []))
    }

    @Test("BMP does not offer metadata fields its encoder discards")
    func bitmapMetadataCannotClaimSuccess() {
        let engine = ImageToolEngine(ffmpeg: nil, naming: MediaToolTests.naming, copier: SpyCopier())
        let bmp = MatrixConversionTests.catalog.format(FormatID("bmp"))
        let jpeg = MatrixConversionTests.catalog.format(FormatID("jpg"))
        #expect(!engine.canRun(.editMetadata, on: [bmp]))
        #expect(!engine.canRun(.editMetadata, on: [jpeg, bmp]))
        #expect(engine.canRun(.editMetadata, on: [jpeg]))
    }
}
