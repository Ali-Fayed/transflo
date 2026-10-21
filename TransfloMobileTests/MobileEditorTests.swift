import Foundation
import PDFKit
import Testing
import TransfloData
import TransfloDomain
@testable import TransfloMobile
import UIKit

@Suite("Mobile alpha tool editors")
struct MobileEditorTests {
    @Test("the mobile catalog includes only working editors and platform engines")
    func catalog() {
        let conversion = MobileConversionFactory()
        let tools = MobileToolFactory(formats: conversion.catalog, suffixes: LocalizedToolSuffixes(language: .english))
        let kinds = Set(tools.catalog.tools.map(\.kind))
        #expect(kinds.contains(.resize) && kinds.contains(.crop) && kinds.contains(.rotate))
        #expect(kinds.contains(.reorganizePages) && kinds.contains(.removeMetadata) && kinds.contains(.rename))
        #expect(kinds.contains(.trim) && kinds.contains(.changeSpeed) && kinds.contains(.mute))
        #expect(!kinds.contains(.normalize) && !kinds.contains(.bleep))
    }

    @Test("an editor schedules only after Apply and full dismissal; cancelling never applies")
    func sessionLifecycle() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let image = try photo(in: root)
        let choices = MobileWheelChoices(markupEditors: StubMarkupEditors())
        var received: [ToolSettings] = []
        choices.edit(.resize, items: [image]) { received.append($0) }
        let model = try #require(choices.session?.model)
        await model.load()
        model.setWidth(100)
        #expect(model.height == 75)
        choices.apply()
        #expect(received.isEmpty && choices.session == nil && choices.isPresented)
        choices.didDismiss()
        #expect(received == [.resize(width: 100, height: 75)] && !choices.isPresented)
        choices.didDismiss()
        #expect(received.count == 1)
        choices.edit(.crop, items: [image]) { received.append($0) }
        choices.cancel()
        choices.didDismiss()
        #expect(received.count == 1)
    }

    @Test("image editors produce real outputs and preserve their source", arguments: [
        ToolKind.resize, .crop, .rotate, .adjust, .addBackground, .removeMetadata, .editMetadata, .compress
    ])
    func imageTools(tool: ToolKind) async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try photo(in: root)
        let original = try Data(contentsOf: source)
        let model = MobileToolEditorModel(tool: tool, items: [source])
        await model.load()
        model.setWidth(200)
        model.brightness = 0.15
        model.title = "Test title"
        model.author = "Test author"
        #expect(model.isValid)
        let runner = MobileToolFactory(formats: MobileConversionFactory().catalog,
                                      suffixes: LocalizedToolSuffixes(language: .english)).makeRunner()
        let output = try #require(try await runner.run(WheelOption(.tool(tool), settings: model.settings),
                                                     on: [source], progress: { _ in }).first)
        let image = try #require(UIImage(contentsOfFile: output.path))
        if tool == .resize { #expect(image.size == CGSize(width: 200, height: 150)) }
        if tool == .rotate { #expect(image.size == CGSize(width: 300, height: 400)) }
        if tool == .crop { #expect(image.size == CGSize(width: 320, height: 240)) }
        #expect(output != source && FileManager.default.fileExists(atPath: output.path))
        #expect(try Data(contentsOf: source) == original)
    }

    @Test("batch collage and image-to-PDF run through the shared Mac engines", arguments: [
        ToolKind.collage, .imagesToPDF
    ])
    func imageBatch(tool: ToolKind) async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try photo(in: root)
        let second = root.appendingPathComponent("second.jpg")
        try FileManager.default.copyItem(at: first, to: second)
        let model = MobileToolEditorModel(tool: tool, items: [first, second])
        await model.load()
        let runner = MobileToolFactory(formats: MobileConversionFactory().catalog,
                                      suffixes: LocalizedToolSuffixes(language: .english)).makeRunner()
        let output = try #require(try await runner.run(WheelOption(.tool(tool), settings: model.settings),
                                                     on: [first, second], progress: { _ in }).first)
        if tool == .imagesToPDF { #expect(PDFDocument(url: output)?.pageCount == 2) }
        if tool == .collage { #expect(UIImage(contentsOfFile: output.path) != nil) }
    }

    @Test("PDF page edits preserve the source and use selected page order", arguments: [
        ToolKind.rotate, .removeMetadata, .editMetadata, .extractPages, .reorganizePages, .split, .merge
    ])
    func pdfTools(tool: ToolKind) async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 120, height: 160)).writePDF(to: source) { context in
            for number in 1...3 {
                context.beginPage()
                ("Page \(number)" as NSString).draw(at: CGPoint(x: 15, y: 40), withAttributes: nil)
            }
        }
        let original = try Data(contentsOf: source)
        var inputs = [source]
        if tool == .merge {
            let second = root.appendingPathComponent("second.pdf")
            try FileManager.default.copyItem(at: source, to: second)
            inputs.append(second)
        }
        let model = MobileToolEditorModel(tool: tool, items: inputs)
        await model.load()
        model.selectedPages = [1]
        model.pages.reverse()
        model.title = "New title"
        model.author = "New author"
        #expect(model.isValid)
        let runner = MobileToolFactory(formats: MobileConversionFactory().catalog,
                                      suffixes: LocalizedToolSuffixes(language: .english)).makeRunner()
        let outputs = try await runner.run(WheelOption(.tool(tool), settings: model.settings),
                                           on: inputs, progress: { _ in })
        let output = try #require(outputs.first)
        let pdf = try #require(PDFDocument(url: output))
        if tool == .extractPages { #expect(pdf.pageCount == 1 && pdf.string?.contains("Page 2") == true) }
        if tool == .reorganizePages { #expect(pdf.page(at: 0)?.string?.contains("Page 3") == true) }
        if tool == .split { #expect(outputs.count == 3 && pdf.pageCount == 1) }
        if tool == .merge { #expect(pdf.pageCount == 6) }
        #expect(try Data(contentsOf: source) == original)
    }

    @Test("rename previews match the actual renamed inbox copies")
    func rename() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try photo(in: root)
        let model = MobileToolEditorModel(tool: .rename, items: [source])
        await model.load()
        model.pattern = "Holiday-{n}"
        let runner = MobileToolFactory(formats: MobileConversionFactory().catalog,
                                      suffixes: LocalizedToolSuffixes(language: .english)).makeRunner()
        let output = try #require(try await runner.run(WheelOption(.tool(.rename), settings: model.settings),
                                                     on: [source], progress: { _ in }).first)
        #expect(output.lastPathComponent == model.renamed[0] + ".jpg")
        #expect(UIImage(contentsOfFile: output.path) != nil)
    }

    private func workspace() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func photo(in root: URL) throws -> URL {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300), format: format).image { context in
            for index in 0..<1200 {
                UIColor(hue: Double(index % 97) / 97, saturation: 0.7, brightness: 0.8, alpha: 1).setFill()
                context.fill(CGRect(x: (index % 40) * 10, y: (index / 40) * 10, width: 10, height: 10))
            }
        }
        let url = root.appendingPathComponent("photo.jpg")
        try #require(image.jpegData(compressionQuality: 1)).write(to: url)
        return url
    }
}
