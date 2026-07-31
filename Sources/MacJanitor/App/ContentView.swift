import SwiftUI

struct ContentView: View {
    @State private var showingLogViewer = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }

            MaintenanceView()
                .tabItem {
                    Label("Maintenance", systemImage: "wrench.and.screwdriver")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .frame(minWidth: 780, minHeight: 520)
        .background {
            // Hidden button so Cmd+Shift+2 opens the log viewer reliably
            Button("") { showingLogViewer = true }
                .keyboardShortcut("2", modifiers: [.command, .shift])
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .sheet(isPresented: $showingLogViewer) {
            LogViewerView()
                .frame(width: 640, height: 520)
        }
    }
}
