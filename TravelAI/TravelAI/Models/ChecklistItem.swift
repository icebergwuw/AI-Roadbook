import SwiftData
import Foundation

@Model
final class ChecklistItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var dayIndex: Int?     // nil = 全局，有值 = 关联第几天

    init(title: String, isCompleted: Bool = false, dayIndex: Int? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.dayIndex = dayIndex
    }
}
