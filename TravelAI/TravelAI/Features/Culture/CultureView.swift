import SwiftUI

struct CultureView: View {
    let trip: Trip

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if let culture = trip.culture, !culture.nodes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(culture.title)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("点击任意节点查看详情")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(AppTheme.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)

                    Divider().background(AppTheme.border)

                    KnowledgeGraphView(culture: culture)
                }
            } else {
                VStack(spacing: 12) {
                    Text("🏛️")
                        .font(.system(size: 48))
                    Text("暂无文化知识内容")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
