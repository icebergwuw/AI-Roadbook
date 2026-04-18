import SwiftUI
import CoreLocation

// MARK: - TripInputController（全局输入状态）
@Observable
final class TripInputController {
    static let shared = TripInputController()

    private static let suggestedDestinations = [
        "京都", "摩洛哥", "冰岛", "巴厘岛", "东京",
        "巴黎", "新西兰", "土耳其", "迪拜", "秘鲁"
    ]

    private init() {
        // 启动时随机预填一个目的地，方便用户直接点飞行
        destination = Self.suggestedDestinations.randomElement() ?? "京都"
    }

    enum ChatStep: Equatable {
        case idle, date, style, confirm
    }

    var chatStep: ChatStep = .idle
    var destination: String
    var selectedDate: Date = .now
    var selectedDays: Int = 3
    var selectedStyle: String = "文化探索"

    // Callback — HomeView / TripListSheet 负责绑定
    var onStartGeneration: ((String, Date, Int, String) -> Void)?

    func reset() {
        chatStep = .idle
        destination = Self.suggestedDestinations.randomElement() ?? "京都"
        selectedDate = .now
        selectedDays = 3
        selectedStyle = "文化探索"
    }
}
