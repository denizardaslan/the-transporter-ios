# Overview

This project is a SwiftUI application that allows users to generate driving telemetry data. It will produce a json file that will record langitute, latitude, speed, distance, tyre tipe, driver name, date and time.

# Core functionalities

1.1 Record button to start recording data
1.2 Live speed display, green background when speed is decreasing, red background when speed is increasing
1.3 Previous speed display graph, show last 60 seconds of speed.
1.4 Saved sessions menu, show all saved sessions, and allow user to delete and share session.
1.5 Settings menu, allow user to set tyre type, driver name.


# Sample Codes
By checking the code, you can see the similar project that I have done before. I want to do like this, but in better way and more follows the design patterns of iOS.

## ContentView.swift
import SwiftUI
import CoreLocation
import Charts

struct ContentView: View {
    @StateObject private var drivingRecorder = DrivingRecorder()
    @EnvironmentObject private var recorderState: RecorderState
    @State private var showFileList = false
    @State private var showSettings = false
    @State private var speedChangeType: SpeedChangeType = .stable // Track speed change
    @State private var lastSpeed: Double?

    var body: some View {
        NavigationView {
            VStack {
                if recorderState.isRecording {
                    VStack {
                        Text("Speed: \(drivingRecorder.currentSpeed, specifier: "%.1f") km/h")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(getSpeedBackgroundColor())
                            .foregroundColor(Color.white)
                        Text("Distance: \(drivingRecorder.totalDistance, specifier: "%.1f") m")
                            .font(.headline)
                            .foregroundColor(Color.white)
                        
                        Chart {
                            ForEach(drivingRecorder.speedData) { dataPoint in
                                LineMark(
                                    x: .value("Second", dataPoint.time, unit: .second),
                                    y: .value("Speed", dataPoint.speed)
                                )
                                .foregroundStyle(Color.blue)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartXScale(domain: chartXRange())
                        .frame(height: 100)
                    }
                    .padding(.top)
                    .onChange(of: drivingRecorder.currentSpeed) {
                        let newSpeed = drivingRecorder.currentSpeed
                        speedChangeType = getSpeedChangeType(newSpeed: newSpeed)
                        lastSpeed = newSpeed
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if recorderState.isRecording {
                        drivingRecorder.stopRecording()
                    } else {
                        drivingRecorder.startRecording()
                    }
                    recorderState.isRecording.toggle()
                }) {
                    Text(recorderState.isRecording ? "Stop Recording" : "Record Driving")
                        .font(.headline)
                        .padding()
                        .background(recorderState.isRecording ? Color.red : Color.blue)
                        .foregroundColor(Color.white)
                        .cornerRadius(10)
                }

                Spacer()
                
                HStack {
                    NavigationLink(destination: SettingsView(), isActive: $showSettings) {
                        EmptyView()
                    }

                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()

                    NavigationLink(destination: FileListView(), isActive: $showFileList) {
                        EmptyView()
                    }

                    Button(action: {
                        showFileList = true
                    }) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Driving Data")
            .background(Color.black)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil, userInfo: ["isRecording": recorderState.isRecording])
        }
    }
    
    func chartXRange() -> ClosedRange<Date> {
        let now = Date()
        let twentySecondsAgo = now.addingTimeInterval(-20)
        return twentySecondsAgo...now
    }
    
    enum SpeedChangeType {
        case increasing, decreasing, stable
    }

    func getSpeedChangeType(newSpeed: Double) -> SpeedChangeType {
        guard let lastSpeed = lastSpeed else { return .stable }

        if newSpeed > lastSpeed {
            return .increasing
        } else if newSpeed < lastSpeed {
            return .decreasing
        } else {
            return .stable
        }
    }

    func getSpeedBackgroundColor() -> Color {
        switch speedChangeType {
        case .increasing:
            return .green
        case .decreasing:
            return .red
        case .stable:
            return .gray
        }
    }
}


##  DrivingDataApp.swift
import SwiftUI

@main
struct DrivingDataApp: App {
    @StateObject private var recorderState = RecorderState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recorderState)
        }
    }
}

## DrivingRecorder.swift
import Foundation
import CoreLocation
import Combine
import UIKit

class DrivingRecorder: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var timer: Timer?

    @Published var currentSession: DrivingData?
    @Published var currentSpeed: Double = 0
    @Published var totalDistance: Double = 0
    @Published var speedData: [SpeedData] = []
    private var lastLocation: CLLocation?
    private var dataIndex = 0
    private var startTime: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()

        // Configure for background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        // Start the location manager when the app becomes active
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func appDidBecomeActive(notification: Notification) {
        if let userInfo = notification.userInfo, let isRecording = userInfo["isRecording"] as? Bool, isRecording {
            locationManager.startUpdatingLocation()
        }
    }

    func startRecording() {
        currentSession = DrivingData(session_id: nextSessionId, session_start: Date().timeIntervalSince1970, data: [], tyreType: AppSettings.shared.selectedTyre, driverName: AppSettings.shared.driverName)
        nextSessionId += 1
        lastLocation = nil
        locationManager.startUpdatingLocation()
        
        dataIndex = 0
        startTime = nil
        totalDistance = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordDataPoint()
        }
    }

    func stopRecording() {
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil

        currentSession?.session_end = Date().timeIntervalSince1970
        if let session = currentSession {
            saveSession(session)
        }
        currentSession = nil
        
        currentSpeed = 0
        totalDistance = 0
        speedData = []
        startTime = nil
    }

    private func recordDataPoint() {
        guard let location = locationManager.location else { return }
        let timestamp = Date().timeIntervalSince1970
        let speed = location.speed >= 0 ? location.speed : 0
        currentSpeed = speed * 3.6

        // Calculate distance from last location only if last location is valid.
        if let lastLocation = lastLocation {
            let distance = lastLocation.distance(from: location)
            totalDistance += distance
        }
        
        // Update last location.
        lastLocation = location

        // Calculate elapsed time since the start of recording
        let currentTime = Date()
        if startTime == nil {
            startTime = currentTime
        }
        let elapsedTime = currentTime.timeIntervalSince(startTime ?? currentTime)

        // Update speed data for the chart
        if speedData.count >= 20 {
            speedData.removeFirst()
        }
        speedData.append(SpeedData(time: Date(), speed: currentSpeed))
        
        let dataPoint = DrivingPoint(index: dataIndex, timestamp: timestamp, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude, speed: speed, distance: totalDistance)

        currentSession?.data.append(dataPoint)
        dataIndex += 1
    }

    private func saveSession(_ session: DrivingData) {
        do {
            // Create a date formatter to format the date and time for the filename
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss" // e.g., 2023-10-27_14-30-45
            let dateString = dateFormatter.string(from: Date())

            // Create the filename with the date and session ID
            let fileName = "\(dateString)_session_\(session.session_id).json"

            // Get the URL for the file in the Documents directory
            let fileURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent(fileName)

            // Encode the session data to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(session)

            // Write the JSON data to the file
            try jsonData.write(to: fileURL)

            print("Session saved to: \(fileURL)")
        } catch {
            print("Error saving session: \(error)")
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates if needed, but data recording is done in the timer
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            print("Location access denied or restricted.")
            // Optionally, show an alert here or trigger a notification to inform the user
        }
    }
    
    func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            // Show an alert explaining that location access is needed
            // You may need to pass a reference to your ContentView or use a notification to trigger the alert
            print("Location access is denied or restricted. Please enable it in Settings.")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break // Authorization is already granted
        }
    }
    
    private var nextSessionId: Int {
        get {
            // Get the last session ID from UserDefaults, or default to 0 if none exists
            let lastSessionId = UserDefaults.standard.integer(forKey: "lastSessionId")
            // Increment the last session ID by 1
            return lastSessionId + 1
        }
        set {
            // Save the new session ID to UserDefaults
            UserDefaults.standard.set(newValue, forKey: "lastSessionId")
        }
    }
}


## FileListView.swift
import SwiftUI

struct FileListView: View {
    @State private var fileURLs: [URL] = []
    @State private var selectedURLs: Set<URL> = []
    @State private var isSharing: Bool = false

    var body: some View {
        NavigationView {
            List(selection: $selectedURLs) { 
                ForEach(fileURLs, id: \.self) { url in
                    Text(url.lastPathComponent)
                }
                .onDelete(perform: deleteFiles) 
            }
            .navigationTitle("Previous Sessions")
            .onAppear(perform: loadFiles)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedURLs.isEmpty {
                        Button("Share") {
                            isSharing = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $isSharing) {
                ShareSheet(activityItems: Array(selectedURLs))
            }
        }
    }

    func loadFiles() {
        do {
            let documentDirectory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let files = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
            fileURLs = files.filter { $0.pathExtension == "json" }
        } catch {
            print("Error loading files: \(error)")
        }
    }

    func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let fileURL = fileURLs[index]
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("Deleted file: \(fileURL)")
            } catch {
                print("Error deleting file: \(error)")
            }
        }
        loadFiles() 
    }
}

## SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        NavigationView {
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
}

## AppSettings.swift
import SwiftUI

enum TyreType: String, CaseIterable, Codable {
    case winter = "Winter"
    case summer = "Summer"
    case allSeason = "All Season"
}

class AppSettings: ObservableObject {
    @AppStorage("selectedTyre") var selectedTyre: TyreType = .summer
    @AppStorage("driverName") var driverName: String = ""

    static let shared = AppSettings()

    private init() {}
}

## RecorderState.swift
import SwiftUI

class RecorderState: ObservableObject {
    @Published var isRecording: Bool = false
}

## Models/DrivingData.swift
import Foundation

struct DrivingData: Codable, Identifiable {
    let id = UUID()
    var session_id: Int
    var session_start: TimeInterval
    var session_end: TimeInterval?
    var data: [DrivingPoint]
    var tyreType: TyreType?
    var driverName: String?
}

struct DrivingPoint: Codable {
    var index: Int
    var timestamp: TimeInterval
    var longitude: Double
    var latitude: Double
    var speed: Double
    var distance: Double

    // Define the order of encoding and decoding
    enum CodingKeys: String, CodingKey {
        case index
        case timestamp
        case longitude
        case latitude
        case speed
        case distance
    }

    // Custom initializer to decode in the correct order
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        longitude = try container.decode(Double.self, forKey: .longitude)
        latitude = try container.decode(Double.self, forKey: .latitude)
        speed = try container.decode(Double.self, forKey: .speed)
        distance = try container.decode(Double.self, forKey: .distance)
    }

    // Custom encoding function to encode in the correct order
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(speed, forKey: .speed)
        try container.encode(distance, forKey: .distance)
    }
    
    init(index: Int, timestamp: TimeInterval, longitude: Double, latitude: Double, speed: Double, distance: Double) {
        self.index = index
        self.timestamp = timestamp
        self.longitude = longitude
        self.latitude = latitude
        self.speed = speed
        self.distance = distance
    }
}


## Models/SpeedData.swift
import Foundation

struct SpeedData: Identifiable {
    let id = UUID()
    let time: Date
    let speed: Double
}


# Current project structure
DrivingData/
├── ContentView.swift          // Main UI, displays speed, distance, chart, buttons
├── DrivingDataApp.swift      // App entry point, creates RecorderState
├── DrivingRecorder.swift     // Handles location, data recording, and saving
├── FileListView.swift         // Displays and manages saved JSON files
├── SettingsView.swift         // Displays app settings (tyre type, driver name)
├── AppSettings.swift          // Manages app settings with @AppStorage
├── RecorderState.swift        // ObservableObject to share recording state
├── Models/                    // (Optional group for data models)
│   ├── DrivingData.swift      // Codable structs for DrivingData and DrivingPoint
│   └── SpeedData.swift        // Model for chart data
├── Supporting Files/          // (Group for other project files)
│   ├── Assets.xcassets         // Image assets and color sets
│   ├── Info.plist             // App configuration file
│   └── Preview Content        // Assets for SwiftUI previews
└── Products/                  // (Group for build products - not directly edited)
    └── DrivingData.app         // The built app