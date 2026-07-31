import Foundation

final class OperationLogger: ObservableObject {
    @Published var entries: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let task: String
        let command: String
        let output: String
        let success: Bool
        let duration: TimeInterval
        let freedBytes: Int64
    }

    private let logDirectory: URL
    private let sessionLogFile: URL

    init(logDirectory: URL? = nil) {
        let logsPath: URL
        if let logDirectory {
            logsPath = logDirectory
        } else {
            logsPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent("MacJanitor", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: logsPath, withIntermediateDirectories: true)
        self.logDirectory = logsPath

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: Date())
        self.sessionLogFile = logsPath.appendingPathComponent("maintenance_\(day).log")

        if !FileManager.default.fileExists(atPath: sessionLogFile.path) {
            FileManager.default.createFile(atPath: sessionLogFile.path, contents: nil)
        }
    }

    func logTask(
        task: String,
        command: String,
        output: String,
        success: Bool,
        duration: TimeInterval,
        freedBytes: Int64 = 0
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            task: task,
            command: command,
            output: output,
            success: success,
            duration: duration,
            freedBytes: freedBytes
        )

        entries.insert(entry, at: 0)
        saveLog(entry: entry)
    }

    private func saveLog(entry: LogEntry) {
        let freed = ByteCountFormatter.string(fromByteCount: entry.freedBytes, countStyle: .file)
        let logLine = """
        [\(entry.timestamp.ISO8601Format())] \(entry.task): \(entry.success ? "SUCCESS" : "FAILED") \
        (\(String(format: "%.2f", entry.duration))s, freed \(freed))
          Command: \(entry.command)
          Output: \(entry.output)
        ---

        """

        guard let data = logLine.data(using: .utf8) else { return }

        if !FileManager.default.fileExists(atPath: sessionLogFile.path) {
            FileManager.default.createFile(atPath: sessionLogFile.path, contents: data)
            return
        }

        guard let handle = try? FileHandle(forWritingTo: sessionLogFile) else {
            try? data.write(to: sessionLogFile)
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }

    func getRecentLogs(count: Int = 50) -> String {
        entries.prefix(count).map { entry in
            let freed = ByteCountFormatter.string(fromByteCount: entry.freedBytes, countStyle: .file)
            return "[\(dateFormatter.string(from: entry.timestamp))] \(entry.task): \(entry.success ? "✓" : "✗") (\(freed))\n  \(entry.output)\n"
        }.joined()
    }

    var directoryURL: URL { logDirectory }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm:ss a"
        return formatter
    }
}
