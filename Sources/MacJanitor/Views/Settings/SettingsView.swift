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
                    Toggle("Deep cache clean", isOn: $maintenanceManager.deepCacheClean)
                    Text("Clears user and app caches even when they were used recently. iCloud, Photos, Music, Messages, passwords, and browser history are never deleted. Turn off to keep caches newer than 7 days.")
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
                        Text("3.1.0")
                    }
                    Text("Clears Trash, regenerable caches, browser caches, logs, temporary files, and developer junk. Personal files, mail, photos, and passwords are left alone.")
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
