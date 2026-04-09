import SwiftData
import Foundation

@Model
final class SOSContact {
    var title: String
    var subtitle: String
    var phone: String
    var emoji: String
    var sortIndex: Int

    init(title: String, subtitle: String, phone: String,
         emoji: String = "📞", sortIndex: Int = 0) {
        self.title = title
        self.subtitle = subtitle
        self.phone = phone
        self.emoji = emoji
        self.sortIndex = sortIndex
    }
}

@Model
final class Tip {
    var content: String
    var sortIndex: Int

    init(content: String, sortIndex: Int = 0) {
        self.content = content
        self.sortIndex = sortIndex
    }
}
