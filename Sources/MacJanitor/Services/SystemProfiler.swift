import Foundation
import AppKit
import IOKit.ps

@MainActor
class SystemProfiler: ObservableObject {
    @Published var systemInfo: SystemInfo = .default
    @Published var timeMachineEnabled: Bool = false
    
    func refreshSystemInfo() {
        checkTimeMachineStatus()
        Task {
            let info = await fetchSystemInfo()
            DispatchQueue.main.async {
                self.systemInfo = info
            }
        }
    }
    
    func checkTimeMachineStatus() {
        Task {
            let (output, status) = await ShellExecutor.execute("tmutil istimeMachineEnabled")
            DispatchQueue.main.async {
                self.timeMachineEnabled = (status == 0 && output?.contains("1") == true)
            }
        }
    }
    
    private func fetchSystemInfo() async -> SystemInfo {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        let buildVersion = await shell("sw_vers -buildVersion") ?? "Unknown"
        let architecture = await shell("uname -m") ?? "Unknown"
        let model = await shell("sysctl -n hw.model") ?? "Unknown"
        let processor = await shell("sysctl -n machdep.cpu.brand_string") ?? "Unknown"
        let memory = await getMemoryInfo()
        let diskSpace = await getDiskSpaceInfo()
        let (batteryLevel, isOnBatteryPower) = await getBatteryInfo()
        
        return SystemInfo(
            macOSVersion: osVersionString,
            buildVersion: buildVersion,
            architecture: architecture,
            model: model,
            processor: processor,
            memory: memory,
            diskSpace: diskSpace,
            batteryLevel: batteryLevel,
            isOnBatteryPower: isOnBatteryPower
        )
    }
    
    private func getMemoryInfo() async -> String {
        let memory = ProcessInfo.processInfo.physicalMemory
        return ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)
    }
    
    private func getDiskSpaceInfo() async -> DiskSpaceInfo {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = Int64(values.volumeAvailableCapacity ?? 0)
            let used = total - available
            return DiskSpaceInfo(total: total, available: available, used: used)
        } catch {
            return DiskSpaceInfo(total: 0, available: 0, used: 0)
        }
    }
    
    private func getBatteryInfo() async -> (Double?, Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        guard let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] else {
            return (nil, false)
        }
        
        let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = info[kIOPSMaxCapacityKey] as? Int ?? 0
        let powerSource = info[kIOPSPowerSourceStateKey] as? String ?? ""
        
        let batteryLevel = maxCapacity > 0 ? Double(currentCapacity) / Double(maxCapacity) * 100 : nil
        let isOnBatteryPower = powerSource == kIOPSACPowerValue ? false : true
        
        return (batteryLevel, isOnBatteryPower)
    }
    
    private func shell(_ command: String) async -> String? {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output
        } catch {
            return nil
        }
    }
}
