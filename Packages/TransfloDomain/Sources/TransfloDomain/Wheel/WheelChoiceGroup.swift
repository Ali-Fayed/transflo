/// A titled group of wedges in Settings › Wheel. Convert groups formats by family; Tools and
/// Actions use one group with no family.
public struct WheelChoiceGroup: Sendable, Equatable {
    public let family: FormatFamily?
    public let options: [WheelOption]

    public init(family: FormatFamily?, options: [WheelOption]) {
        self.family = family
        self.options = options
    }
}
