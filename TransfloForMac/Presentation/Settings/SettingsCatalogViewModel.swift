import Foundation
import Observation
import TransfloDomain

/// A read-only view of the same capability-filtered catalog that drives conversion wheels.
@Observable
final class SettingsCatalogViewModel {
    let catalog: ConversionCatalog
    var search = ""
    var selectedFormat: FormatID?
    var family: FormatFamily = .image

    init(catalog: ConversionCatalog) { self.catalog = catalog }

    var groups: [(family: FormatFamily, formats: [FormatDescriptor])] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return FormatFamily.allCases.compactMap { family in
            let formats = catalog.formats.filter {
                $0.family == family && (query.isEmpty
                    || $0.displayName.localizedCaseInsensitiveContains(query)
                    || $0.extensions.contains { $0.localizedCaseInsensitiveContains(query) })
            }
            return formats.isEmpty ? nil : (family, formats)
        }
    }

    var selection: FormatDescriptor? { selectedFormat.flatMap(catalog.format) }
    var targets: [FormatDescriptor] { selectedFormat.map(catalog.targets(from:)) ?? [] }
    var matrixSources: [FormatDescriptor] { catalog.formats.filter { $0.family == family } }
    var matrixTargets: [FormatDescriptor] {
        let ids = Set(matrixSources.flatMap { catalog.targets(from: $0.id).map(\.id) })
        return catalog.formats.filter { ids.contains($0.id) }
    }

    func supports(_ source: FormatID, _ target: FormatID) -> Bool {
        catalog.path(from: source, to: target) != nil
    }

    static func label(for family: FormatFamily) -> L10nKey {
        switch family {
        case .image: .familyImage
        case .audio: .familyAudio
        case .video: .familyVideo
        case .document: .familyDocument
        case .presentation: .familyPresentation
        case .spreadsheet: .familySpreadsheet
        case .subtitle: .familySubtitle
        case .archive: .familyArchive
        }
    }
}
