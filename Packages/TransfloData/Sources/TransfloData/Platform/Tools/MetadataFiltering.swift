import Foundation
import ImageIO
import PDFKit
import TransfloDomain

enum MetadataFiltering {
    static func category(_ key: String) -> MetadataCategory {
        let key = key.lowercased()
        let locations = [
            "gps", "location", "latitude", "longitude", "altitude", "city", "country", "province", "sublocation"
        ]
        if locations.contains(where: key.contains) { return .location }
        if ["exif", "camera", "maker", "model", "lens", "serial", "exposure", "iso"].contains(where: key.contains) {
            return .camera
        }
        if ["title", "author", "artist", "comment", "description", "subject", "copyright", "iptc", "keywords"]
            .contains(where: key.contains) { return .descriptive }
        return .other
    }

    private static func childCategory(_ key: String, parent: MetadataCategory) -> MetadataCategory {
        let child = category(key)
        if child == .location { return .location }
        return parent == .other ? child : parent
    }

    static func image(_ properties: [CFString: Any], removing categories: Set<MetadataCategory>) -> [CFString: Any] {
        if categories == Set(MetadataCategory.allCases) { return [:] }
        var result = properties
        for (key, value) in properties {
            if let dictionary = value as? [String: Any] {
                let parent = category(key as String)
                let kept = dictionary.filter { child, _ in
                    let group = childCategory(child, parent: parent)
                    return !categories.contains(group)
                }
                result[key] = kept.isEmpty ? nil : kept
            } else if categories.contains(category(key as String)) {
                // Keep the structural properties required to describe the encoded pixels.
                if !structural.contains(key as String) { result[key] = nil }
            }
        }
        return result
    }

    static let structural: Set<String> = ["PixelWidth", "PixelHeight", "Orientation", "ColorModel",
                                          "Depth", "HasAlpha", "ProfileName", "DPIWidth", "DPIHeight"]

    static func entries(_ properties: [CFString: Any]) -> [MetadataEntry] {
        properties.flatMap { key, value -> [MetadataEntry] in
            let parent = category(key as String)
            if let dictionary = value as? [String: Any] {
                return dictionary.map { child, value in
                    MetadataEntry(name: "\(key).\(child)", value: String(describing: value),
                                  category: childCategory(child, parent: parent))
                }
            }
            guard !structural.contains(key as String) else { return [] }
            return [MetadataEntry(name: key as String, value: String(describing: value), category: parent)]
        }.sorted { $0.name < $1.name }
    }
}
