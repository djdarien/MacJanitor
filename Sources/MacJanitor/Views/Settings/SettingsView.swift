import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    @State private var showingLogViewer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)

            GroupBox("Cleanup") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Default to dry run", isOn: $maintenanceManager.dryRun)
                    Text("Dry run scans and reports sizes without deleting. Turn off for real cleanup.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("Developer") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Open Log Viewer (⌘⇧2)") {
                        showingLogViewer = true
                    }
                    Text("Logs: ~/Library/Logs/MacJanitor/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("About") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("3.0.0")
                    }
                    Text("Real cleanup engine: FileManager trash/caches + admin shell for system tasks.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingLogViewer) {
            LogViewerView()
                .frame(width: 640, height: 520)
        }
    }
}
