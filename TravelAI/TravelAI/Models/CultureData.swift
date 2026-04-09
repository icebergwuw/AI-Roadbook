import SwiftData
import Foundation

@Model
final class CultureData {
    var type: String       // mythology_tree / dynasty_tree / general
    var title: String
    @Relationship(deleteRule: .cascade) var nodes: [CultureNode]

    init(type: String, title: String) {
        self.type = type
        self.title = title
        self.nodes = []
    }
}

@Model
final class CultureNode: Identifiable {
    var nodeId: String
    var name: String
    var subtitle: String
    var nodeDescription: String
    var emoji: String
    var parentId: String?
    var relationType: String?  // 父子 / 夫妻 / 兄弟

    init(nodeId: String, name: String, subtitle: String,
         description: String, emoji: String,
         parentId: String? = nil, relationType: String? = nil) {
        self.nodeId = nodeId
        self.name = name
        self.subtitle = subtitle
        self.nodeDescription = description
        self.emoji = emoji
        self.parentId = parentId
        self.relationType = relationType
    }
}
