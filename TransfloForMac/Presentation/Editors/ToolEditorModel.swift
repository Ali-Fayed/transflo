import TransfloDomain

/// What every tool editor's view model provides to the shared scaffold.
protocol ToolEditorModel: AnyObject {
    /// The settings to run with, or `nil` while the input is incomplete or invalid.
    var settings: ToolSettings? { get }
    /// Loads the preview and file facts.
    func load() async
}
