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
        .frame(minWidth: 700, minHeight: 400)
        .keyboardShortcut("2", modifiers: [.command, .shift])
        .sheet(isPresented: $showingLogViewer) {
            LogViewerView()
                .frame(width: 600, height: 500)
        }
    }
}
