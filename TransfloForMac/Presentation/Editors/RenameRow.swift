/// One line of the rename preview: the current name and the new one.
struct RenameRow: Identifiable, Equatable {
    let id: Int
    let old: String
    let new: String
}
