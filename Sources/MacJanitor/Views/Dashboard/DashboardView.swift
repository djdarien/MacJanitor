import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var systemProfiler: SystemProfiler
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("System Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            SystemInfoGrid()
            
            DiskSpaceView()

            if !maintenanceManager.lastRunSummary.isEmpty {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.green)
                    Text(maintenanceManager.lastRunSummary)
                        .font(.callout)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            systemProfiler.refreshSystemInfo()
        }
    }
}

struct SystemInfoGrid: View {
    @EnvironmentObject var systemProfiler: SystemProfiler
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
            InfoCard(title: "macOS Version", value: systemProfiler.systemInfo.macOSVersion, icon: "applelogo")
            InfoCard(title: "Build Version", value: systemProfiler.systemInfo.buildVersion, icon: "hammer")
            InfoCard(title: "Architecture", value: systemProfiler.systemInfo.architecture, icon: "cpu")
            InfoCard(title: "Model", value: systemProfiler.systemInfo.model, icon: "desktopcomputer")
            InfoCard(title: "Processor", value: systemProfiler.systemInfo.processor, icon: "memorychip")
            InfoCard(title: "Memory", value: systemProfiler.systemInfo.memory, icon: "sdcard")
        }
    }
}

struct DiskSpaceView: View {
    @EnvironmentObject var systemProfiler: SystemProfiler
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Disk Space")
                .font(.title2)
                .fontWeight(.semibold)
            
            ProgressView(value: systemProfiler.systemInfo.diskSpace.usedPercentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle())
            
            HStack {
                Text("Used: \(ByteCountFormatter.string(fromByteCount: systemProfiler.systemInfo.diskSpace.used, countStyle: .file))")
                Spacer()
                Text("Available: \(ByteCountFormatter.string(fromByteCount: systemProfiler.systemInfo.diskSpace.available, countStyle: .file))")
                Spacer()
                Text("Total: \(ByteCountFormatter.string(fromByteCount: systemProfiler.systemInfo.diskSpace.total, countStyle: .file))")
            }
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }
            Text(value)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
    }
}