import SwiftUI

@main
struct TheTransporter_TelemetryApp: App {
    @StateObject private var recorderState = RecorderState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recorderState)
        }
    }
} 