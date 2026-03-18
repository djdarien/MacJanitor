import SwiftUI

struct SettingsView: View {
    @State private var scheduleEnabled = false
    @State private var selectedTime = Date()
    @State private var devModeEnabled = false
    @State private var showingLogViewer = false
    @State private var logContent: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Form {
                Toggle("Enable Scheduled Maintenance", isOn: $scheduleEnabled)
                
                if scheduleEnabled {
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                }
                
                Toggle("Developer Mode", isOn: $devModeEnabled)
                    .foregroundColor(.purple)
                
                if devModeEnabled {
                    Section(header: Text("Developer Tools")) {
                        Button("Open Log Viewer") {
                            showingLogViewer = true
                            loadLogs()
                        }
                        
                        Button("Refresh Logs") {
                            loadLogs()
                        }
                        
                        Button("Clear Logs") {
                            clearLogs()
                        }
                        
                        Text("Log Location: ~/Library/Logs/MacJanitor/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("5.0.0")
                    }
                }
            }
            
            if devModeEnabled && showingLogViewer {
                LogViewerPanel(logContent: $logContent)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingLogViewer) {
            LogViewerView()
                .frame(width: 600, height: 500)
        }
    }
    
    private func loadLogs() {
        Task {
            let (output, _) = await ShellExecutor.execute("tail -n 100 ~/Library/Logs/MacJanitor/*.log 2>/dev/null || echo 'No logs found'")
            DispatchQueue.main.async {
                logContent = output ?? "No logs available"
            }
        }
    }
    
    private func clearLogs() {
        Task {
            await ShellExecutor.execute("rm -rf ~/Library/Logs/MacJanitor/*.log 2>/dev/null")
            logContent = "Logs cleared"
        }
    }
}

struct LogViewerPanel: View {
    @Binding var logContent: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Live Log Output")
                .font(.headline)
            
            ScrollView {
                Text(logContent.isEmpty ? "No logs loaded yet..." : logContent)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
    }
}