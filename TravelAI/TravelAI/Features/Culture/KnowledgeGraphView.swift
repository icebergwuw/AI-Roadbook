import SwiftUI

struct KnowledgeGraphView: View {
    let culture: CultureData
    @State private var selectedNode: CultureNode?

    private var levels: [[CultureNode]] {
        var result: [[CultureNode]] = []
        var remaining = culture.nodes
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
        if !remaining.isEmpty { result.append(remaining) }
        return result
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(levels.enumerated()), id: \.offset) { levelIdx, level in
                    VStack(spacing: 0) {
                        if levelIdx > 0 {
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(PageAccent.culture.opacity(0.35))
                                    .frame(width: 1, height: 18)
                                Circle()
                                    .fill(PageAccent.culture.opacity(0.5))
                                    .frame(width: 5, height: 5)
                            }
                            .padding(.bottom, 8)
                        }

                        HStack(alignment: .top, spacing: 18) {
                            ForEach(level, id: \.nodeId) { node in
                                KnowledgeNodeView(node: node, isRoot: levelIdx == 0) {
                                    selectedNode = node
                                }
                            }
                        }

                        if levelIdx < levels.count - 1 && level.count > 1 {
                            ZStack {
                                Rectangle()
                                    .fill(PageAccent.culture.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.horizontal, 44)
                            }
                            .padding(.top, 14)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .padding(AppTheme.padding * 2)
        }
        .sheet(item: $selectedNode) { node in NodeDetailView(node: node) }
    }
}

private struct KnowledgeNodeView: View {
    let node: CultureNode
    let isRoot: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(isRoot ? PageAccent.cultureBG : AppTheme.cardBG)
                        .frame(width: isRoot ? 68 : 54, height: isRoot ? 68 : 54)
                        .overlay(
                            Circle().stroke(
                                isRoot ? PageAccent.culture.opacity(0.5) : AppTheme.border,
                                lineWidth: isRoot ? 2 : 1
                            )
                        )
                        .shadow(
                            color: isRoot ? PageAccent.culture.opacity(0.2) : Color.black.opacity(0.06),
                            radius: isRoot ? 10 : 4
                        )
                    Text(node.emoji).font(.system(size: isRoot ? 28 : 22))
                }
                .scaleEffect(pressed ? 0.92 : 1.0)

                Text(node.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isRoot ? PageAccent.culture : AppTheme.textPrimary)
                    .multilineTextAlignment(.center).lineLimit(2)

                if !node.subtitle.isEmpty {
                    Text(node.subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textTertiary)
                        .multilineTextAlignment(.center).lineLimit(1)
                }
            }
            .frame(width: isRoot ? 84 : 70)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.95 : 1.0)
        .animation(AppTheme.animSnappy, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}
