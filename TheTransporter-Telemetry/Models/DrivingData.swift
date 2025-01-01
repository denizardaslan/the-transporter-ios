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