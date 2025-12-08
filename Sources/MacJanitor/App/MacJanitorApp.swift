import SwiftUI

@main
struct MacJanitorApp: App {
    @StateObject private var maintenanceManager = MaintenanceManager()
    @StateObject private var systemProfiler = SystemProfiler()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(maintenanceManager)
                .environmentObject(systemProfiler)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}