import TransfloDomain

/// Presentation-only groups. Jobs and saved visibility/pin preferences still use individual tools.
enum WheelToolGroup: String, CaseIterable {
    case geometry, appearance, markup, read, metadata, names, arrange, timeline, audio, recipes

    var title: L10nKey {
        switch self {
        case .geometry: .wheelGroupGeometry
        case .appearance: .wheelGroupAppearance
        case .markup: .wheelGroupMarkup
        case .read: .wheelGroupRead
        case .metadata: .wheelGroupMetadata
        case .names: .wheelGroupNames
        case .arrange: .wheelGroupArrange
        case .timeline: .wheelGroupTimeline
        case .audio: .wheelGroupAudio
        case .recipes: .wheelGroupRecipes
        }
    }

    var symbol: AppSymbol {
        switch self {
        case .geometry: .resize
        case .appearance: .adjust
        case .markup: .annotate
        case .read: .extractText
        case .metadata: .editMetadata
        case .names: .rename
        case .arrange: .reorganizePages
        case .timeline: .trim
        case .audio: .normalize
        case .recipes: .recipe
        }
    }

    static func group(for option: WheelOption) -> WheelToolGroup? {
        switch option.kind {
        case .recipe: return .recipes
        case .tool(let tool): return tools[tool]
        case .format, .action: return nil
        }
    }

    private static let tools: [ToolKind: WheelToolGroup] = [
        .resize: .geometry, .crop: .geometry, .rotate: .geometry, .upscale: .geometry,
        .adjust: .appearance, .removeBackground: .appearance, .addBackground: .appearance,
        .annotate: .markup, .redact: .markup,
        .readCode: .read, .extractText: .read, .describeImage: .read,
        .editMetadata: .metadata, .removeMetadata: .metadata, .rename: .names, .smartRename: .names,
        .collage: .arrange, .imagesToPDF: .arrange, .merge: .arrange, .split: .arrange,
        .reorganizePages: .arrange, .extractPages: .arrange,
        .trim: .timeline, .changeSpeed: .timeline, .snapshot: .timeline,
        .mute: .audio, .normalize: .audio, .bleep: .audio, .channels: .audio
    ]

    static func rootSlots(for options: [WheelOption]) -> [WheelSlot] {
        var seen: Set<WheelToolGroup> = []
        return options.compactMap { option in
            guard let group = group(for: option) else { return .option(option) }
            guard seen.insert(group).inserted else { return nil }
            let members = options.filter { Self.group(for: $0) == group }
            return group == .recipes || members.count > 1 ? .group(group) : .option(option)
        }
    }
}
