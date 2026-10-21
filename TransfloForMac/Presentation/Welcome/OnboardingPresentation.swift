import TransfloDomain

/// Sample choices and copy for each wheel. The key binding itself is read live by the view model.
enum OnboardingPresentation {
    static func wedges(for wheel: WheelKind) -> [WheelWedgeContent] {
        switch wheel {
        case .convert:
            ["PNG", "WEBP", "HEIC", "TIFF", "AVIF", "PDF"].map {
                WheelWedgeContent(id: $0, label: .verbatim($0), symbol: nil)
            }
        case .tools:
            [WheelSlot.option(WheelOption(.tool(.compress))), .group(.geometry), .group(.appearance),
             .group(.metadata), .group(.names), .group(.recipes)].map(WheelPresentation.wedge(for:))
        case .actions:
            ActionKind.allCases.map { WheelPresentation.wedge(for: WheelOption(.action($0))) }
        }
    }

    static func description(for wheel: WheelKind) -> L10nKey {
        switch wheel {
        case .convert: .onboardingConvertDescription
        case .tools: .onboardingToolsDescription
        case .actions: .onboardingActionsDescription
        }
    }

    static func keyName(_ key: ModifierKey) -> L10nKey {
        switch key {
        case .shift: .onboardingKeyShift
        case .command: .onboardingKeyCommand
        case .control: .onboardingKeyControl
        case .option: .onboardingKeyOption
        }
    }
}
