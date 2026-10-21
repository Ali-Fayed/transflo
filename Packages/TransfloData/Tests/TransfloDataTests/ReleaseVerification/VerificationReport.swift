import Foundation

struct VerificationReport {
    struct Row: Codable {
        let id: String
        let status: String
        let detail: String
        let outputs: [String]
        let seconds: Double
    }

    let root: URL
    var rows: [Row] = []

    init(root: URL) {
        self.root = root
        if let data = try? Data(contentsOf: root.appendingPathComponent("results.json")),
           let saved = try? JSONDecoder().decode([Row].self, from: data) { rows = saved }
    }

    func directory(_ id: String) throws -> URL {
        let name = id + "-" + UUID().uuidString.prefix(8)
        let directory = root.appendingPathComponent("results").appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    mutating func append(
        _ id: String, status: String, detail: String, outputs: [URL] = [], started: Date
    ) {
        rows.removeAll { $0.id == id }
        rows.append(Row(id: id, status: status, detail: detail,
                        outputs: outputs.map { $0.path.replacingOccurrences(of: root.path + "/", with: "") },
                        seconds: Date().timeIntervalSince(started)))
        print("VERIFY \(status) \(id): \(detail)")
        try? save(finished: false)
    }

    mutating func append(_ id: String, error: any Error, outputs: [URL] = [], started: Date) {
        let reason = String(describing: error)
        let blocked = reason.contains("automationDenied") || reason.contains("fixtureUnavailable")
        append(id, status: blocked ? "BLOCKED" : "FAIL", detail: reason, outputs: outputs, started: started)
    }

    func save(finished: Bool) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rows).write(to: root.appendingPathComponent("results.json"), options: .atomic)
        let counts = Dictionary(grouping: rows, by: \.status).mapValues(\.count)
        let lines = rows.map { "| \($0.id) | \($0.status) | \($0.detail.replacingOccurrences(of: "|", with: "/")) |" }
        let text = """
        # Transflo release verification

        State: \(finished ? "Finished" : "In progress"). Cases recorded: \(rows.count). Counts: \(counts).

        This run exercises the source engines and validates generated outputs on this Mac.
        It does not certify arbitrary inputs, UI gestures, App Sandbox, distribution signing, or other macOS versions.
        PASS means an output opened with the target decoder. EXPECTED means an intentional no-content result.
        BLOCKED and FAIL are not passing coverage. Tool settings/edge cases also require the existing regression suites.

        Originals in the parent folder are copied; Rename operates only on per-case copies.
        Legacy binary fixtures are from Apache POI test-data (Apache License 2.0):
        https://github.com/apache/poi/tree/trunk/test-data

        | Case | Result | Detail |
        | --- | --- | --- |
        \(lines.joined(separator: "\n"))

        """
        try Data(text.utf8).write(to: root.appendingPathComponent("REPORT.md"), options: .atomic)
    }
}
