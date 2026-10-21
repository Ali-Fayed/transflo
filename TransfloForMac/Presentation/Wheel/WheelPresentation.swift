import TransfloDomain

/// Maps wheel domain values to what the wheel displays.
enum WheelPresentation {
    static func wedge(for option: WheelOption) -> WheelWedgeContent {
        switch option.kind {
        case .format(let format):
            WheelWedgeContent(id: option.id, label: .verbatim(format.displayName), symbol: nil)
        case .tool(let tool):
            WheelWedgeContent(id: option.id, label: .key(wedgeLabel(for: tool)), symbol: toolSymbols[tool])
        case .action(let action):
            WheelWedgeContent(id: option.id, label: .key(label(for: action)), symbol: symbol(for: action))
        case .recipe(let recipe):
            WheelWedgeContent(id: option.id, label: .verbatim(recipe.name), symbol: .recipe)
        }
    }

    static func wedge(for slot: WheelSlot) -> WheelWedgeContent {
        switch slot {
        case .option(let option): wedge(for: option)
        case .group(let group): WheelWedgeContent(id: "group.\(group.rawValue)", label: .key(group.title),
                                                symbol: group.symbol)
        case .back: WheelWedgeContent(id: "back", label: .key(.wheelBack), symbol: .arrowBackward)
        case .more: WheelWedgeContent(id: "more", label: .key(.wheelMore), symbol: .more)
        }
    }

    static func title(for wheel: WheelKind) -> L10nKey {
        switch wheel {
        case .convert: .wheelConvert
        case .tools: .wheelTools
        case .actions: .wheelActions
        }
    }

    /// The macOS glyph for a modifier (⇧ ⌘ ⌃ ⌥). Glyphs are symbols, not translatable copy.
    static func glyph(for key: ModifierKey) -> String {
        switch key {
        case .shift: "⇧"
        case .command: "⌘"
        case .control: "⌃"
        case .option: "⌥"
        }
    }

    /// Wedge label per tool. `WheelViewModelTests` checks every tool has one.
    /// The name on a wheel petal: a shorter form where the full name can't fit a crowded ring.
    static func wedgeLabel(for tool: ToolKind) -> L10nKey {
        shortToolLabels[tool] ?? toolLabels[tool] ?? .wheelTools
    }

    private static let shortToolLabels: [ToolKind: L10nKey] = [
        .addBackground: .toolAddBackgroundShort, .removeBackground: .toolRemoveBackgroundShort
    ]

    static let toolLabels: [ToolKind: L10nKey] = [
        .compress: .toolCompress,
        .resize: .toolResize,
        .crop: .toolCrop,
        .rotate: .toolRotate,
        .adjust: .toolAdjust,
        .annotate: .toolAnnotate,
        .redact: .toolRedact,
        .removeBackground: .toolRemoveBackground,
        .addBackground: .toolAddBackground,
        .readCode: .toolReadCode,
        .imagesToPDF: .toolImagesToPDF,
        .collage: .toolCollage,
        .trim: .toolTrim,
        .changeSpeed: .toolChangeSpeed,
        .split: .toolSplit,
        .merge: .toolMerge,
        .snapshot: .toolSnapshot,
        .mute: .toolMute,
        .normalize: .toolNormalize,
        .bleep: .toolBleep,
        .channels: .toolChannels,
        .reorganizePages: .toolReorganizePages,
        .extractPages: .toolExtractPages,
        .editMetadata: .toolEditMetadata,
        .removeMetadata: .toolRemoveMetadata,
        .rename: .toolRename,
        .extractText: .toolExtractText,
        .describeImage: .toolDescribeImage,
        .smartRename: .toolSmartRename,
        .upscale: .toolUpscale,
        .extractArchive: .toolExtractArchive
    ]

    /// Wedge symbol per tool.
    static let toolSymbols: [ToolKind: AppSymbol] = [
        .compress: .compress,
        .resize: .resize,
        .crop: .crop,
        .rotate: .rotate,
        .adjust: .adjust,
        .annotate: .annotate,
        .redact: .redact,
        .removeBackground: .removeBackground,
        .addBackground: .addBackground,
        .readCode: .readCode,
        .imagesToPDF: .imagesToPDF,
        .collage: .collage,
        .trim: .trim,
        .changeSpeed: .changeSpeed,
        .split: .split,
        .merge: .merge,
        .snapshot: .snapshot,
        .mute: .mute,
        .normalize: .normalize,
        .bleep: .bleep,
        .channels: .channels,
        .reorganizePages: .reorganizePages,
        .extractPages: .extractPages,
        .editMetadata: .editMetadata,
        .removeMetadata: .removeMetadata,
        .rename: .rename,
        .extractText: .extractText,
        .describeImage: .describeImage,
        .smartRename: .smartRename,
        .upscale: .upscale,
        .extractArchive: .extractArchive
    ]

    static func label(for action: ActionKind) -> L10nKey {
        switch action {
        case .airDrop: .actionAirDrop
        case .float: .actionFloat
        case .archive: .actionArchive
        case .copy: .actionCopy
        case .move: .actionMove
        case .copyPath: .actionCopyPath
        case .terminal: .actionTerminal
        }
    }

    private static func symbol(for action: ActionKind) -> AppSymbol {
        switch action {
        case .airDrop: .airDrop
        case .float: .float
        case .archive: .extractArchive
        case .copy: .copy
        case .move: .move
        case .copyPath: .copyPath
        case .terminal: .terminal
        }
    }
}
