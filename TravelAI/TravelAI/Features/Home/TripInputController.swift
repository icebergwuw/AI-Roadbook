import SwiftUI
import CoreLocation

// MARK: - 出行方式
enum TransportMode: String, CaseIterable {
    case plane  = "plane"
    case train  = "train"
    case drive  = "drive"

    var label: String {
        switch self { case .plane: "飞机"; case .train: "高铁"; case .drive: "自驾" }
    }
    var icon: String {
        switch self { case .plane: "airplane"; case .train: "tram.fill"; case .drive: "car.fill" }
    }
    var emoji: String {
        switch self { case .plane: "✈️"; case .train: "🚄"; case .drive: "🚗" }
    }
}

// MARK: - TripInputController（全局输入状态）
@Observable
final class TripInputController {
    static let shared = TripInputController()

    private static let suggestedDestinations = [
        "京都", "摩洛哥", "冰岛", "巴厘岛", "东京",
        "巴黎", "新西兰", "土耳其", "迪拜", "秘鲁"
    ]

    private init() {
        destination = Self.suggestedDestinations.randomElement() ?? "京都"
        // 从设置读默认值
        selectedStyle = Self.defaultStyleFromSettings()
        transportMode = Self.defaultTransportFromSettings()
    }

    enum ChatStep: Equatable {
        case idle, date, confirm
    }

    var chatStep: ChatStep = .idle
    var destination: String
    var selectedDate: Date = .now
    var selectedDays: Int = 3
    var selectedStyle: String
    var transportMode: TransportMode
    /// 每次 reset() 自增，TravelInputBar 用 onChange 监听来同步 inputText
    var resetToken: Int = 0

    // Callback — HomeView / TripListSheet 负责绑定
    var onStartGeneration: ((String, Date, Int, String, TransportMode) -> Void)?

    func reset() {
        chatStep = .idle
        destination = Self.suggestedDestinations.randomElement() ?? "京都"
        selectedDate = .now
        selectedDays = 3
        selectedStyle = Self.defaultStyleFromSettings()
        transportMode = Self.defaultTransportFromSettings()
        resetToken += 1
    }

    // 从 UserDefaults 读默认风格（保持和 SettingsView 的 tag 一致）
    static func defaultStyleFromSettings() -> String {
        let raw = UserDefaults.standard.string(forKey: "travelai.defaultTravelStyle") ?? "文化探索"
        return raw
    }

    static func defaultTransportFromSettings() -> TransportMode {
        let raw = UserDefaults.standard.string(forKey: "travelai.defaultTransport") ?? "plane"
        return TransportMode(rawValue: raw) ?? .plane
    }
}
