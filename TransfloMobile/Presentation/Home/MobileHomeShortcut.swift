/// Home's shortcut cards, in order.
enum MobileHomeShortcut: String, CaseIterable, Identifiable {
    case photos, files, activity, recipes
    var id: String { rawValue }
}
