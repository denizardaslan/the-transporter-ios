import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Picker("Tyre Type", selection: $settings.selectedTyre) {
                ForEach(TyreType.allCases, id: \.self) { tyre in
                    Text(tyre.rawValue).tag(tyre)
                }
            }
            
            TextField("Driver Name", text: $settings.driverName)
        }
        .navigationTitle("Settings")
    }
} 