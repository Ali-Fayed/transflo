/// Crop box shape presets.
enum CropAspect: Hashable, CaseIterable {
    case free
    case original
    case square
    case fourThree
    case sixteenNine
    case nineSixteen
    case threeFour
    case fourFive
    case threeTwo
    case twoThree

    /// Width ÷ height in pixels, or `nil` for free cropping.
    func ratio(imageWidth: Int, imageHeight: Int) -> Double? {
        switch self {
        case .free: nil
        case .original: imageHeight > 0 ? Double(imageWidth) / Double(imageHeight) : nil
        case .square: 1
        case .fourThree: 4.0 / 3.0
        case .sixteenNine: 16.0 / 9.0
        case .nineSixteen: 9.0 / 16.0
        case .threeFour: 3.0 / 4.0
        case .fourFive: 4.0 / 5.0
        case .threeTwo: 3.0 / 2.0
        case .twoThree: 2.0 / 3.0
        }
    }
}
