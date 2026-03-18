import Foundation

class OperationLogger: ObservableObject {
    @Published var entries: [LogEntry] = []
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let task: String
        let command: String
        let output: String
        let success: Bool
        let duration: TimeInterval
    }
    
    private let logDirectory: URL
    
    init() {
        let logsPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
            .appendingPathComponent("MacJanitor")
        try? FileManager.default.createDirectory(at: logsPath, withIntermediateDirectories: true)
        logDirectory = logsPath
    }
    
    func logTask(task: String, command: String, output: String, success: Bool, duration: TimeInterval) {
        let entry = LogEntry(
            timestamp: Date(),
            task: task,
            command: command,
            output: output,
            success: success,
            duration: duration
        )
        
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)
        }
        
        saveLog(entry: entry)
    }
    
    private func saveLog(entry: LogEntry) {
        let logFile = logDirectory
            .appendingPathComponent("maintenance_\(Date().ISO8601Format().colonReplacement("-")).log")
        
        let logLine = "[\(entry.timestamp.ISO8601Format())] \(entry.task): \(entry.success ? "SUCCESS" : "FAILED") - \(entry.duration)s\n\(entry.output)\n---\n"
        
        if var data = logLine.data(using: .utf8) {
            try? data.append(to: logFile)
        }
    }
    
    func getRecentLogs(count: Int = 50) -> String {
        return entries.prefix(count).map { entry in
            "[\(dateFormatter.string(from: entry.timestamp))] \(entry.task): \(entry.success ? "✓" : "✗")\n  Command: \(entry.command)\n  Output: \(entry.output)\n"
        }.joined()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm:ss a"
        return formatter
    }
}

extension Data {
    mutating func append(to file: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: file) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            try write(fileHandle)
        } else {
            try write(to: file)
        }
    }
    
    private mutating func write(_ fileHandle: FileHandle) throws {
        try fileHandle.write(contentsOf: self)
    }
}

extension String {
    func colonReplacement(_ replacement: String) -> String {
        return self.replacingOccurrences(of: ":", with: replacement)
    }
}
