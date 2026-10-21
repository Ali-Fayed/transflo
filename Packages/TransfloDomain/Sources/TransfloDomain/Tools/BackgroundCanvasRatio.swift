/// Canvas shapes for image presentation, without cropping the source picture.
public enum BackgroundCanvasRatio: Sendable, Hashable, CaseIterable {
    case automatic, square, sixteenNine, fourFive, nineSixteen, fourThree, threeFour, threeTwo, twoThree

    public var ratio: Double? {
        switch self {
        case .automatic: nil
        case .square: 1
        case .sixteenNine: 16.0 / 9.0
        case .fourFive: 4.0 / 5.0
        case .nineSixteen: 9.0 / 16.0
        case .fourThree: 4.0 / 3.0
        case .threeFour: 3.0 / 4.0
        case .threeTwo: 3.0 / 2.0
        case .twoThree: 2.0 / 3.0
        }
    }
}
