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

        // Update speed data for the chart
        if speedData.count >= 60 {
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
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
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
        }
    }
    
    func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            print("Location access is denied or restricted. Please enable it in Settings.")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break // Authorization is already granted
        }
    }
    
    private var nextSessionId: Int {
        get {
            let lastSessionId = UserDefaults.standard.integer(forKey: "lastSessionId")
            return lastSessionId + 1
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastSessionId")
        }
    }
} 