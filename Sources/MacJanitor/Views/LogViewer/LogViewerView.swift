import SwiftUI

struct LogViewerView: View {
    @State private var logContent: String = ""
    @State private var isLoading = false
    @State private var logDirectoryExists: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Maintenance Logs")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    loadLogs()
                }
                .disabled(isLoading)
                
                Button("Clear Logs") {
                    clearLogs()
                }
            }
            
            if logDirectoryExists {
                ScrollView {
                    if isLoading {
                        ProgressView("Loading logs...")
                    } else {
                        if logContent.isEmpty {
                            Text("No log entries yet. Run maintenance to create logs.")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            Text(logContent)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(minHeight: 300, maxHeight: .infinity)
                .padding()
                .background(Color(NSColor.textBackgroundColor).roundedCorner(8))
                
                HStack {
                    Text("Last updated: \(Date(), formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Location: ~/Library/Logs/MacJanitor/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Log directory not found")
                        .font(.headline)
                    
                    Text("The log directory will be created when you run your first maintenance task.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Log Folder in Finder") {
                        openLogFolder()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .padding()
        .onAppear {
            checkLogDirectory()
            loadLogs()
        }
    }
    
    private func checkLogDirectory() {
        let fileManager = FileManager.default
        let logsPath = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
            .appendingPathComponent("MacJanitor")
        
        logDirectoryExists = fileManager.fileExists(atPath: logsPath.path)
        
        if !logDirectoryExists {
            try? fileManager.createDirectory(at: logsPath, withIntermediateDirectories: true)
            logDirectoryExists = true
        }
    }
    
    private func loadLogs() {
        isLoading = true
        Task {
            let (output, _) = await ShellExecutor.execute("find ~/Library/Logs/MacJanitor -name '*.log' -exec cat {} \\; 2>/dev/null | tail -n 100")
            DispatchQueue.main.async {
                if let output = output, !output.isEmpty {
                    logContent = output
                } else {
                    logContent = ""
                }
                isLoading = false
            }
        }
    }
    
    private func clearLogs() {
        Task {
            await ShellExecutor.execute("rm -f ~/Library/Logs/MacJanitor/*.log")
            logContent = ""
            checkLogDirectory()
        }
    }
    
    private func openLogFolder() {
        let logsPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
            .appendingPathComponent("MacJanitor")
        
        try? FileManager.default.createDirectory(at: logsPath, withIntermediateDirectories: true)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logsPath.path)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter
    }
}

extension View {
    func roundedCorner(_ radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius))
    }
}
