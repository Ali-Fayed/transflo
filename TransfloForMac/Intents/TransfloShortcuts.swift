import AppIntents

/// Phrases that offer Transflo's actions in Spotlight, Siri and the Shortcuts app with no setup. Siri
/// needs the app's name in each phrase; formats and recipes can be spoken ("Convert this to PNG with
/// Transflo"), and Siri asks for the files when none are shared with it.
struct TransfloShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ConvertFilesIntent(), phrases: [
            "Convert files with \(.applicationName)",
            "Convert this to \(\.$format) with \(.applicationName)",
            "Convert this image to \(\.$format) with \(.applicationName)",
            "Convert to \(\.$format) with \(.applicationName)",
            "Make this a \(\.$format) with \(.applicationName)"
        ], shortTitle: LocalizedStringResource("intent.convert.short", defaultValue: "Convert Files"),
                    systemImageName: "arrow.triangle.2.circlepath")
        AppShortcut(intent: CompressFilesIntent(), phrases: [
            "Compress files with \(.applicationName)",
            "Compress this with \(.applicationName)",
            "Compress this image with \(.applicationName)",
            "Make this smaller with \(.applicationName)"
        ], shortTitle: LocalizedStringResource("intent.compress.short", defaultValue: "Compress Files"),
                    systemImageName: "arrow.down.right.and.arrow.up.left")
        AppShortcut(intent: RunRecipeIntent(), phrases: [
            "Run a \(.applicationName) recipe",
            "Run \(\.$recipe) with \(.applicationName)"
        ], shortTitle: LocalizedStringResource("intent.recipe.short", defaultValue: "Run Recipe"),
                    systemImageName: "wand.and.rays")
    }
}
