import Observation
import TransfloDomain

/// The applied visual preferences. Token reads participate in SwiftUI observation across windows.
@Observable
final class InterfaceStyle {
    static let shared = InterfaceStyle()
    private(set) var preferences = InterfaceCustomization.standard

    func apply(_ preferences: InterfaceCustomization) {
        self.preferences = preferences.validated
    }
}
