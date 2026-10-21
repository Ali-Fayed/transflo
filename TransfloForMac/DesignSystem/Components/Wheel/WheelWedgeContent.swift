/// What one wedge of `AppRadialWheel` shows.
struct WheelWedgeContent: Identifiable {
    /// Translatable copy, or data such as a format code.
    enum Label: Equatable {
        case key(L10nKey)
        case verbatim(String)
    }

    let id: String
    let label: Label
    let symbol: AppSymbol?
}
