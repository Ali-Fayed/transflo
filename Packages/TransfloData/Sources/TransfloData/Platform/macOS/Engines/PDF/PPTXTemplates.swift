#if os(macOS)
/// Static PresentationML parts: the slide template (OOXML `sldMaster`), a blank layout and a
/// minimal Transflo theme.
enum PPTXTemplates {
    static let groupProperties = "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
        + "<p:grpSpPr/>"

    static func slideTemplate(namespaces: String) -> String {
        OOXMLParts.declaration + "<p:sldMaster \(namespaces)><p:cSld><p:spTree>\(groupProperties)</p:spTree></p:cSld>"
            + "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\" "
            + "accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" "
            + "folHlink=\"folHlink\"/>"
            + "<p:sldLayoutIdLst><p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/></p:sldLayoutIdLst></p:sldMaster>"
    }

    static func layout(namespaces: String) -> String {
        OOXMLParts.declaration + "<p:sldLayout \(namespaces) type=\"blank\" preserve=\"1\">"
            + "<p:cSld name=\"Blank\"><p:spTree>\(groupProperties)</p:spTree></p:cSld>"
            + "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>"
    }

    static let theme: String = {
        let colors = [
            ("dk2", "1B1D1F"), ("lt2", "F6F4EF"), ("accent1", "136F63"), ("accent2", "3FB8A5"), ("accent3", "6B6862"),
            ("accent4", "B3261E"), ("accent5", "2C3034"), ("accent6", "CFCBC2"), ("hlink", "136F63"),
            ("folHlink", "6B6862")
        ].map { "<a:\($0.0)><a:srgbClr val=\"\($0.1)\"/></a:\($0.0)>" }.joined()
        let font = "<a:latin typeface=\"Helvetica Neue\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/>"
        let fill = "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
        let line = "<a:ln w=\"9525\">\(fill)</a:ln>"
        let effect = "<a:effectStyle><a:effectLst/></a:effectStyle>"
        return OOXMLParts.declaration
            + "<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"Transflo\">"
            + "<a:themeElements><a:clrScheme name=\"Transflo\">"
            + "<a:dk1><a:sysClr val=\"windowText\" lastClr=\"000000\"/></a:dk1>"
            + "<a:lt1><a:sysClr val=\"window\" lastClr=\"FFFFFF\"/></a:lt1>\(colors)</a:clrScheme>"
            + "<a:fontScheme name=\"Transflo\"><a:majorFont>\(font)</a:majorFont><a:minorFont>\(font)</a:minorFont>"
            + "</a:fontScheme><a:fmtScheme name=\"Transflo\">"
            + "<a:fillStyleLst>\(fill)\(fill)\(fill)</a:fillStyleLst>"
            + "<a:lnStyleLst>\(line)\(line)\(line)</a:lnStyleLst>"
            + "<a:effectStyleLst>\(effect)\(effect)\(effect)</a:effectStyleLst>"
            + "<a:bgFillStyleLst>\(fill)\(fill)\(fill)</a:bgFillStyleLst>"
            + "</a:fmtScheme></a:themeElements></a:theme>"
    }()
}
#endif
