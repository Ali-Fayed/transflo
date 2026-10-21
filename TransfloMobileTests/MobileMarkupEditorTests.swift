import Foundation
import PDFKit
import Testing
import TransfloData
import TransfloDomain
@testable import TransfloMobile
import UIKit

@Suite("Mobile Annotate and Redact")
struct MobileMarkupEditorTests {
    private let conversion = MobileConversionFactory()

    @Test("the mobile catalog offers Annotate and Redact")
    func catalog() {
        let tools = MobileToolFactory(formats: conversion.catalog, suffixes: LocalizedToolSuffixes(language: .english))
        let kinds = Set(tools.catalog.tools.map(\.kind))
        #expect(kinds.contains(.annotate) && kinds.contains(.redact))
    }

    @Test("the factory builds markup editors only for markup tools")
    func factory() {
        let factory = makeFactory()
        let item = URL(fileURLWithPath: "/tmp/photo.png")
        guard case .annotate = factory.editor(for: .annotate, item: item) else { Issue.record("no annotate"); return }
        guard case .redact = factory.editor(for: .redact, item: item) else { Issue.record("no redact"); return }
        #expect(factory.editor(for: .resize, item: item) == nil)
    }

    @Test("a redaction box applies only after Apply and dismissal")
    func redactApplies() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let choices = MobileWheelChoices(markupEditors: makeFactory())
        var received: [ToolSettings] = []
        choices.edit(.redact, items: [try photo(in: root)]) { received.append($0) }
        let session = try #require(choices.markup)
        guard case .redact(let model) = session.editor else { Issue.record("not redact"); return }
        await model.load()
        // Then nothing applies before there is a box
        choices.applyMarkup()
        #expect(choices.markup != nil && received.isEmpty)
        model.begin(at: UnitPoint(x: 0.1, y: 0.1))
        model.move(to: UnitPoint(x: 0.5, y: 0.4))
        model.end()
        choices.applyMarkup()
        #expect(choices.markup == nil && received.isEmpty)
        choices.didDismiss()
        guard case .redact(let boxes) = try #require(received.first) else { Issue.record("not redact"); return }
        #expect(boxes.count == 1 && !choices.isPresented)
    }

    @Test("cancelling a markup editor never applies")
    func cancel() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let choices = MobileWheelChoices(markupEditors: makeFactory())
        var applied = false
        choices.edit(.annotate, items: [try photo(in: root)]) { _ in applied = true }
        #expect(choices.markup != nil && choices.isPresented)
        choices.cancel()
        choices.didDismiss()
        #expect(choices.markup == nil && !applied && !choices.isPresented)
    }

    @Test("a tool without an editor opens nothing")
    func missingEditor() {
        let choices = MobileWheelChoices(markupEditors: StubMarkupEditors())
        choices.edit(.annotate, items: [URL(fileURLWithPath: "/tmp/a.png")]) { _ in }
        #expect(choices.markup == nil && !choices.isPresented)
    }

    @Test("still previews report image size, PDF pages, and nothing for unreadable files")
    func previews() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let provider = StillToolPreviewProvider()
        let png = conversion.catalog.format(forFileExtension: "png")
        let image = await provider.preview(of: try photo(in: root), format: png)
        #expect(image.width == 400 && image.height == 300 && image.thumbnail != nil)
        let pdf = root.appendingPathComponent("doc.pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 140)).writePDF(to: pdf) { context in
            context.beginPage()
            context.beginPage()
        }
        let pdfFormat = conversion.catalog.format(forFileExtension: "pdf")
        #expect(await provider.preview(of: pdf, format: pdfFormat).pageCount == 2)
        #expect(await provider.pagePreview(of: pdf, index: 1).thumbnail != nil)
        let broken = root.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: broken)
        #expect(await provider.preview(of: broken, format: png) == .empty)
        #expect(await provider.pagePreview(of: pdf, index: 9) == .empty)
    }

    private func makeFactory() -> MobileMarkupEditorFactory {
        MobileMarkupEditorFactory(formats: conversion.catalog, previews: StillToolPreviewProvider())
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
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let url = root.appendingPathComponent("photo.png")
        try #require(image.pngData()).write(to: url)
        return url
    }
}
