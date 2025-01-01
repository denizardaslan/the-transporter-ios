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