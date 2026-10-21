import CoreImage
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

struct VerificationFixtures: Sendable {
    let root: URL
    var home: URL { root.appendingPathComponent("fixtures") }

    func file(_ format: String) -> URL {
        if ["ppt", "xls"].contains(format) {
            return home.appendingPathComponent("legacy/sample.\(format)")
        }
        return home.appendingPathComponent(format).appendingPathComponent(
            "source.\(format == "clipping" ? "textClipping" : format)"
        )
    }

    func prepare(report: inout VerificationReport) async throws {
        let formats = MatrixConversionTests.catalog.formats.map { $0.id.rawValue }.sorted()
        for format in formats {
            let started = Date()
            do {
                let url = file(format)
                if !FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true)
                    if format == "html" {
                        try Data("<html><body><h1>Hello Transflo</h1><p>مرحبا</p></body></html>".utf8).write(to: url)
                    } else if ["xls", "ppt"].contains(format) {
                        throw VerificationSupport.Failure.fixtureUnavailable(format)
                    } else {
                        _ = try await VerificationSupport.timed {
                            [try await MediaFixtures.make(format, in: url.deletingLastPathComponent())]
                        }
                    }
                }
                report.append("fixture-\(format)", status: "PASS", detail: "Fixture available",
                              outputs: [url], started: started)
            } catch { report.append("fixture-\(format)", error: error, started: started) }
        }
        try makeQR()
    }

    private func makeQR() throws {
        let output = home.appendingPathComponent("qr.png")
        guard !FileManager.default.fileExists(atPath: output.path) else { return }
        let filter = try #require(CIFilter(name: "CIQRCodeGenerator"))
        filter.setValue(Data("https://transfloformac.ali-fayed.com/verification".utf8), forKey: "inputMessage")
        let code = try #require(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let padded = code.composited(over: CIImage(color: .white).cropped(to: code.extent.insetBy(dx: -48, dy: -48)))
        let image = try #require(CIContext().createCGImage(padded, from: padded.extent))
        try PNGWriter.write(image, to: output)
        let pdf = home.appendingPathComponent("qr.pdf")
        try PDFImageWriter.write(image, pointSize: CGSize(width: image.width, height: image.height), to: pdf)
    }

    /// A portrait provides a real foreground subject for segmentation; a QR provides a positive detection case.
    func toolSource(_ tool: ToolKind, format: String, directory: URL) async throws -> URL {
        if tool == .readCode {
            let source = home.appendingPathComponent(format == "pdf" ? "qr.pdf" : "qr.png")
            let destination = directory.appendingPathComponent("code.\(format)")
            if format == "pdf" || format == "png" {
                try FileManager.default.copyItem(at: source, to: destination)
            } else {
                let image = try #require(CGImageSourceCreateWithURL(source as CFURL, nil).flatMap {
                    CGImageSourceCreateImageAtIndex($0, 0, nil)
                })
                try ImageFileWriter(ffmpeg: MediaFixtures.ffmpeg).write(image, format: format, to: destination)
            }
            return destination
        }
        if tool == .removeBackground {
            let portrait = root.deletingLastPathComponent().appendingPathComponent("image.png")
            let image = try #require(CGImageSourceCreateWithURL(portrait as CFURL, nil).flatMap {
                CGImageSourceCreateImageAtIndex($0, 0, nil)
            })
            let destination = directory.appendingPathComponent("portrait.\(format)")
            try ImageFileWriter(ffmpeg: MediaFixtures.ffmpeg).write(image, format: format, to: destination)
            return destination
        }
        let source = file(format)
        let input = directory.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: input)
        return input
    }
}
