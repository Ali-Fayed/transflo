import AppIntents
import TransfloDomain

/// Shortcuts: convert files to another format.
struct ConvertFilesIntent: AppIntent {
    static let title = LocalizedStringResource("intent.convert.title", defaultValue: "Convert Files")
    static let description = IntentDescription(
        LocalizedStringResource(
            "intent.convert.description",
            defaultValue: "Converts files to another format on your device and returns the results."
        )
    )

    @Parameter(title: LocalizedStringResource("intent.files", defaultValue: "Files"))
    var files: [IntentFile]

    @Parameter(title: LocalizedStringResource("intent.format", defaultValue: "Format"))
    var format: FormatEntity

    @Dependency private var services: TransfloIntentServices

    static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$files) to \(\.$format)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        guard let target = services.catalog.format(FormatID(format.id)) else {
            throw await IntentFiles.failure(.unsupported)
        }
        do throws(JobError) {
            let outputs = try await services.perform(WheelOption(.format(target)), on: IntentFiles.inputs(files))
            return .result(value: IntentFiles.outputs(outputs))
        } catch {
            throw await IntentFiles.failure(error)
        }
    }
}
