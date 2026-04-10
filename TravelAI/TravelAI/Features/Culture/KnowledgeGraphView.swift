import SwiftUI

struct KnowledgeGraphView: View {
    let culture: CultureData
    @State private var selectedNode: CultureNode?

    // Build level-based tree from flat node list
    private var levels: [[CultureNode]] {
        var result: [[CultureNode]] = []
        var remaining = culture.nodes

        // Level 0: root nodes (no parent)
        var currentLevel = remaining.filter { $0.parentId == nil }
        remaining.removeAll { $0.parentId == nil }

        while !currentLevel.isEmpty {
            result.append(currentLevel)
            let parentIds = Set(currentLevel.map { $0.nodeId })
            let nextLevel = remaining.filter { n in
                guard let p = n.parentId else { return false }
                return parentIds.contains(p)
            }
            remaining.removeAll { n in
                guard let p = n.parentId else { return false }
                return parentIds.contains(p)
            }
            currentLevel = nextLevel
        }

        // Append any remaining orphaned nodes
        if !remaining.isEmpty {
            result.append(remaining)
        }

        return result
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 32) {
                ForEach(Array(levels.enumerated()), id: \.offset) { levelIdx, level in
                    VStack(spacing: 4) {
                        if levelIdx > 0 {
                            // Connector line above
                            Rectangle()
                                .fill(AppTheme.border)
                                .frame(width: 1, height: 20)
                        }

                        HStack(spacing: 20) {
                            ForEach(level, id: \.nodeId) { node in
                                Button {
                                    selectedNode = node
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(AppTheme.cardBackground)
                                                .frame(width: 56, height: 56)
                                                .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                                            Text(node.emoji)
                                                .font(.title2)
                                        }
                                        Text(node.name)
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textPrimary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                        Text(node.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.textSecondary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 72)
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.padding * 2)
        }
        .sheet(item: $selectedNode) { node in
            NodeDetailView(node: node)
        }
    }
}
