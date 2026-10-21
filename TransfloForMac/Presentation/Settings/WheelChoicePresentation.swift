import TransfloDomain

/// How Settings › Wheel names its choices: format codes as they are, tools and actions by their
/// full names with their wheel symbols, and Convert's groups by format family.
enum WheelChoicePresentation {
    static func group(for choices: WheelChoiceGroup) -> WheelVisibilityViewModel.Group {
        WheelVisibilityViewModel.Group(
            title: choices.family.map(title(for:)),
            rows: choices.options.map { option in
                WheelVisibilityViewModel.Row(option: option, label: label(for: option),
                                             symbol: WheelPresentation.wedge(for: option).symbol)
            }
        )
    }

    static func label(for option: WheelOption) -> AppTextContent {
        switch option.kind {
        case .format(let format): .verbatim(format.displayName)
        case .tool(let tool): .key(WheelPresentation.toolLabels[tool] ?? WheelPresentation.wedgeLabel(for: tool))
        case .action(let action): .key(WheelPresentation.label(for: action))
        case .recipe(let recipe): .verbatim(recipe.name)
        }
    }

    static func title(for family: FormatFamily) -> L10nKey {
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
