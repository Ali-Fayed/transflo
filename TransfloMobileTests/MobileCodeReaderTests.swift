import CoreImage.CIFilterBuiltins
import Foundation
import Testing
import TransfloData
import TransfloDomain
import TransfloDomainTestSupport
@testable import TransfloMobile
import UIKit

@Suite("Mobile code reader")
struct MobileCodeReaderTests {
    @Test("the mobile QR tool scans real pixels and copies the decoded value")
    func qrCode() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("Transflo mobile alpha".utf8)
        let code = try #require(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let pixels = try #require(CIContext().createCGImage(code, from: code.extent))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: pixels.width + 64, height: pixels.height + 64),
                                            format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: pixels.width + 64, height: pixels.height + 64))
            context.cgContext.interpolationQuality = .none
            UIImage(cgImage: pixels).draw(at: CGPoint(x: 32, y: 32))
        }
        let source = root.appendingPathComponent("code.png")
        try #require(image.pngData()).write(to: source)
        let copier = SpyTextCopier()
        let naming = ToolOutputNaming(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()),
                                      suffixes: LocalizedToolSuffixes(language: .english))
        let engine = ImageToolEngine(ffmpeg: nil, naming: naming, copier: copier)
        let formatInfo = MobileConversionFactory().catalog.format(forFileExtension: "png")
        let outputs = try await engine.run(ToolRequest(tool: .readCode, settings: .none,
                                                      items: [ToolItem(url: source, format: formatInfo)]),
                                           progress: { _ in })
        #expect(outputs.isEmpty)
        #expect(copier.copied == ["Transflo mobile alpha"])
    }
}
