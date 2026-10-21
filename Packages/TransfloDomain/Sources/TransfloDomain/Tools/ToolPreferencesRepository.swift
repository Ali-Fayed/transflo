/// Repository for the defaults used by instant tools and their output naming.
public protocol ToolPreferencesRepository: ToolNameStyleProviding {
    func loadCompressionGoal() -> CompressionGoal
    func saveCompressionGoal(_ goal: CompressionGoal)
    func saveNameStyle(_ style: ToolNameStyle)
}
