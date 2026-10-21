import CoreGraphics
import PDFKit
import TransfloDomain

/// Page-level PDF edits: annotations, true redaction, page order, document metadata.
/// Annotations and redaction boxes target the first page (the one the editor shows).
enum PDFPageEditing {
    static func annotate(_ document: PDFDocument, with annotations: [Annotation], pageIndex: Int = 0) {
        guard let page = document.page(at: pageIndex) else { return }
        let bounds = page.bounds(for: .mediaBox)
        for annotation in annotations {
            guard let mark = pdfAnnotation(annotation, bounds: bounds, rotation: page.rotation) else { continue }
            page.addAnnotation(mark)
        }
    }

    /// Replaces the first page with a flattened image carrying the boxes, so the covered text is gone.
    static func redact(_ document: PDFDocument, boxes: [NormalizedRect], pageIndex: Int = 0) throws(JobError) {
        guard let page = document.page(at: pageIndex) else { throw .failed }
        let rendered = try PDFPageImageExporter.render(page, dpi: 200)
        guard let flattened = ImageMarkup.redact(rendered, boxes: boxes) else { throw .failed }
        let points = page.bounds(for: .mediaBox).size
        let upright = page.rotation % 180 == 0 ? points : CGSize(width: points.height, height: points.width)
        let image = PlatformGraphics.image(flattened, size: upright)
        guard let replacement = PDFPage(image: image) else { throw .failed }
        document.removePage(at: pageIndex)
        document.insert(replacement, at: pageIndex)
    }

    /// A new document with `indices` (zero-based) in that order.
    static func pages(_ indices: [Int], from document: PDFDocument) throws(JobError) -> PDFDocument {
        guard !indices.isEmpty else { throw .nothingFound }
        guard indices.allSatisfy({ (0..<document.pageCount).contains($0) }) else { throw .incompatibleSelection }
        let valid = indices
        let result = PDFDocument()
        for index in valid {
            if let page = document.page(at: index)?.copy() as? PDFPage { result.insert(page, at: result.pageCount) }
        }
        return result
    }

    static func setMetadata(_ values: [MetadataField: String], on document: PDFDocument) {
        var attributes = document.documentAttributes ?? [:]
        let keys: [MetadataField: PDFDocumentAttribute] = [
            .title: .titleAttribute, .author: .authorAttribute, .comment: .subjectAttribute
        ]
        for (field, value) in values {
            guard let key = keys[field] else { continue }
            attributes[key] = value.isEmpty ? nil : value
        }
        document.documentAttributes = attributes
    }

    private static func pdfAnnotation(_ annotation: Annotation, bounds: CGRect, rotation: Int) -> PDFAnnotation? {
        let points = annotation.points.map {
            pagePoint(CGPoint(x: $0.x, y: $0.y), bounds: bounds, rotation: rotation)
        }
        let color = PlatformGraphics.color(ImageMarkup.color(annotation.color))
        let weight = max(1, annotation.weight * min(bounds.width, bounds.height))
        guard let first = points.first else { return nil }
        let box = points.reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
            .insetBy(dx: -weight * 4, dy: -weight * 4)
        let mark: PDFAnnotation
        switch annotation.kind {
        case .rectangle:
            let square = box.insetBy(dx: weight * 4, dy: weight * 4)
            mark = PDFAnnotation(bounds: square, forType: .square, withProperties: nil)
        case .arrow:
            mark = PDFAnnotation(bounds: box, forType: .line, withProperties: nil)
            mark.startPoint = CGPoint(x: first.x - box.minX, y: first.y - box.minY)
            let end = points.last ?? first
            mark.endPoint = CGPoint(x: end.x - box.minX, y: end.y - box.minY)
            mark.endLineStyle = .closedArrow
        case .freehand:
            mark = PDFAnnotation(bounds: box, forType: .ink, withProperties: nil)
            mark.add(PlatformGraphics.polyline(points.map { CGPoint(x: $0.x - box.minX, y: $0.y - box.minY) }))
        case .text(let text):
            let size = CGSize(width: max(CGFloat(text.count) * weight * 2.6, 40), height: weight * 6)
            let display = rotation % 180 == 0 ? bounds.size : CGSize(width: bounds.height, height: bounds.width)
            guard let anchor = annotation.points.first else { return nil }
            let opposite = pagePoint(CGPoint(x: anchor.x + size.width / display.width,
                                               y: anchor.y + size.height / display.height),
                                     bounds: bounds, rotation: rotation)
            let textBox = CGRect(x: min(first.x, opposite.x), y: min(first.y, opposite.y),
                                 width: abs(first.x - opposite.x), height: abs(first.y - opposite.y))
            mark = PDFAnnotation(bounds: textBox, forType: .freeText, withProperties: nil)
            mark.setValue(((rotation % 360) + 360) % 360,
                          forAnnotationKey: PDFAnnotationKey(rawValue: "Rotate"))
            mark.contents = text
            mark.font = PlatformFont.boldSystemFont(ofSize: weight * 4)
            mark.fontColor = color
        }
        if case .text = annotation.kind {
            mark.color = .clear
        } else {
            mark.color = color
        }
        let border = PDFBorder()
        border.lineWidth = weight
        mark.border = border
        return mark
    }

    /// Inverts the page's display rotation before mapping top-left preview coordinates to PDF space.
    private static func pagePoint(_ point: CGPoint, bounds: CGRect, rotation: Int) -> CGPoint {
        let unit: CGPoint
        switch ((rotation % 360) + 360) % 360 {
        case 90: unit = CGPoint(x: point.y, y: point.x)
        case 180: unit = CGPoint(x: 1 - point.x, y: point.y)
        case 270: unit = CGPoint(x: 1 - point.y, y: 1 - point.x)
        default: unit = CGPoint(x: point.x, y: 1 - point.y)
        }
        return CGPoint(x: bounds.minX + unit.x * bounds.width, y: bounds.minY + unit.y * bounds.height)
    }
}
