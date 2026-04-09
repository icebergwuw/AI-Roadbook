import SwiftData
import Foundation

@Model
final class Message {
    var id: UUID
    var role: String   // user / assistant
    var content: String
    var createdAt: Date

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
    }
}
