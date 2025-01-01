//
//  ContentView.swift
//  TheTransporter-Telemetry
//
//  Created by Deniz Arda Aslan on 1.01.2025.
//

import SwiftUI
import CoreLocation
import Charts

struct ContentView: View {
    @StateObject private var drivingRecorder = DrivingRecorder()
    @EnvironmentObject private var recorderState: RecorderState
    @State private var showFileList = false
    @State private var showSettings = false
    @State private var speedChangeType: SpeedChangeType = .stable
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
                    .onChange(of: drivingRecorder.currentSpeed) { newSpeed in
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
    }
    
    func chartXRange() -> ClosedRange<Date> {
        let now = Date()
        let twentySecondsAgo = now.addingTimeInterval(-60)
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
            return .red
        case .decreasing:
            return .green
        case .stable:
            return .gray
        }
    }
}

#Preview {
    ContentView()
}
