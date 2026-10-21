import ImageIO
import TransfloDomain

/// Maps title / author / comment onto IPTC and TIFF properties (empty values clear them).
/// ImageIO mirrors the TIFF description into the IPTC caption, so the description holds the comment.
enum ImageMetadataWriter {
    static func properties(_ base: [CFString: Any], applying values: [MetadataField: String]) -> [CFString: Any] {
        var properties = base
        var iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]
        var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        for (field, value) in values {
            let stored: Any = value.isEmpty ? kCFNull as Any : value
            switch field {
            case .title:
                iptc[kCGImagePropertyIPTCObjectName] = stored
            case .author:
                iptc[kCGImagePropertyIPTCByline] = value.isEmpty ? kCFNull as Any : [value]
                tiff[kCGImagePropertyTIFFArtist] = stored
            case .comment:
                iptc[kCGImagePropertyIPTCCaptionAbstract] = stored
                tiff[kCGImagePropertyTIFFImageDescription] = stored
            }
        }
        properties[kCGImagePropertyIPTCDictionary] = iptc
        properties[kCGImagePropertyTIFFDictionary] = tiff
        return properties
    }
}
