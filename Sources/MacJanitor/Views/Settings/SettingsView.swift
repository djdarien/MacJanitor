import SwiftUI

struct SettingsView: View {
    @State private var scheduleEnabled = false
    @State private var selectedTime = Date()
    
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
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("5.0.0")
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}