#if os(macOS)
import Foundation
import TransfloDomain

/// Writes a PresentationML (.pptx) deck with one full-bleed picture per slide.
enum PPTXWriter {
    static let pointsToEMU = 12_700
    static let slideWidthEMU = 12_192_000
    private static let main = "http://schemas.openxmlformats.org/presentationml/2006/main"
    private static let drawing = "http://schemas.openxmlformats.org/drawingml/2006/main"
    private static let namespaces = "xmlns:a=\"\(drawing)\" xmlns:r=\"\(OOXMLParts.relationshipNamespace)\" "
        + "xmlns:p=\"\(main)\""

    /// - Parameters:
    ///   - slides: PNG data for each slide, in order.
    ///   - aspectRatio: Slide height ÷ width.
    static func write(slides: [Data], aspectRatio: Double, to destination: URL) throws(JobError) {
        guard !slides.isEmpty else { throw .failed }
        let height = Int((Double(slideWidthEMU) * aspectRatio).rounded())
        var files: [String: String] = [
            "[Content_Types].xml": contentTypes(count: slides.count),
            "_rels/.rels": OOXMLParts.rootRelationships(target: "ppt/presentation.xml"),
            "ppt/presentation.xml": presentation(count: slides.count, height: height),
            "ppt/_rels/presentation.xml.rels": presentationRelationships(count: slides.count),
            "ppt/slideMasters/slideMaster1.xml": PPTXTemplates.slideTemplate(namespaces: namespaces),
            "ppt/slideMasters/_rels/slideMaster1.xml.rels": relationships([
                ("slideLayout", "../slideLayouts/slideLayout1.xml"), ("theme", "../theme/theme1.xml")
            ]),
            "ppt/slideLayouts/slideLayout1.xml": PPTXTemplates.layout(namespaces: namespaces),
            "ppt/slideLayouts/_rels/slideLayout1.xml.rels": relationships([
                ("slideMaster", "../slideMasters/slideMaster1.xml")
            ]),
            "ppt/theme/theme1.xml": PPTXTemplates.theme
        ]
        var images: [String: Data] = [:]
        for (index, image) in slides.enumerated() {
            let number = index + 1
            files["ppt/slides/slide\(number).xml"] = slide(number: number, height: height)
            files["ppt/slides/_rels/slide\(number).xml.rels"] = relationships([
                ("slideLayout", "../slideLayouts/slideLayout1.xml"), ("image", "../media/image\(number).png")
            ])
            images["ppt/media/image\(number).png"] = image
        }
        try OOXMLParts.package(files, binaries: images, to: destination)
    }

    private static func slide(number: Int, height: Int) -> String {
        OOXMLParts.declaration + "<p:sld \(namespaces)><p:cSld><p:spTree>" + PPTXTemplates.groupProperties
            + "<p:pic><p:nvPicPr><p:cNvPr id=\"2\" name=\"Page \(number)\"/>"
            + "<p:cNvPicPr><a:picLocks noChangeAspect=\"1\"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>"
            + "<p:blipFill><a:blip r:embed=\"rId2\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>"
            + "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"\(slideWidthEMU)\" cy=\"\(height)\"/></a:xfrm>"
            + "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr></p:pic>"
            + "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>"
    }

    private static func presentation(count: Int, height: Int) -> String {
        let slides = (1...count).map { "<p:sldId id=\"\(255 + $0)\" r:id=\"rId\($0 + 1)\"/>" }.joined()
        return OOXMLParts.declaration + "<p:presentation \(namespaces) saveSubsetFonts=\"1\">"
            + "<p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rId1\"/></p:sldMasterIdLst>"
            + "<p:sldIdLst>\(slides)</p:sldIdLst>"
            + "<p:sldSz cx=\"\(slideWidthEMU)\" cy=\"\(height)\"/><p:notesSz cx=\"6858000\" cy=\"9144000\"/>"
            + "</p:presentation>"
    }

    private static func presentationRelationships(count: Int) -> String {
        var entries = [("slideMaster", "slideMasters/slideMaster1.xml")]
        entries += (1...count).map { ("slide", "slides/slide\($0).xml") }
        entries.append(("theme", "theme/theme1.xml"))
        return relationships(entries)
    }

    private static func relationships(_ entries: [(type: String, target: String)]) -> String {
        let items = entries.enumerated().map { index, entry in
            "<Relationship Id=\"rId\(index + 1)\" Type=\"\(OOXMLParts.relationshipNamespace)/\(entry.type)\" "
                + "Target=\"\(entry.target)\"/>"
        }.joined()
        return OOXMLParts.declaration + OOXMLParts.relationshipsOpen + items + "</Relationships>"
    }

    private static func contentTypes(count: Int) -> String {
        let prefix = "application/vnd.openxmlformats-officedocument.presentationml"
        let slides = (1...count).map {
            "<Override PartName=\"/ppt/slides/slide\($0).xml\" ContentType=\"\(prefix).slide+xml\"/>"
        }.joined()
        return OOXMLParts.declaration
            + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
            + OOXMLParts.defaultContentTypes
            + "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"\(prefix).presentation.main+xml\"/>"
            + "<Override PartName=\"/ppt/slideMasters/slideMaster1.xml\" ContentType=\"\(prefix).slideMaster+xml\"/>"
            + "<Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\" ContentType=\"\(prefix).slideLayout+xml\"/>"
            + "<Override PartName=\"/ppt/theme/theme1.xml\" "
            + "ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>"
            + slides + "</Types>"
    }
}
#endif
