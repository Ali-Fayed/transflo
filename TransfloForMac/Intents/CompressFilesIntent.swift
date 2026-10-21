import AppIntents
import TransfloDomain

/// Shortcuts: compress files with the Output Defaults from Settings.
struct CompressFilesIntent: AppIntent {
    static let title = LocalizedStringResource("intent.compress.title", defaultValue: "Compress Files")
    static let description = IntentDescription(
        LocalizedStringResource("intent.compress.description",
                                defaultValue: "Compresses images, video, audio or PDFs with your Output Defaults.")
    )

    @Parameter(title: LocalizedStringResource("intent.files", defaultValue: "Files"))
    var files: [IntentFile]

    @Dependency private var services: TransfloIntentServices

    static var parameterSummary: some ParameterSummary {
        Summary("Compress \(\.$files)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        do throws(JobError) {
            let outputs = try await services.perform(WheelOption(.tool(.compress)), on: IntentFiles.inputs(files))
            return .result(value: IntentFiles.outputs(outputs))
        } catch {
            throw await IntentFiles.failure(error)
        }
    }
}
