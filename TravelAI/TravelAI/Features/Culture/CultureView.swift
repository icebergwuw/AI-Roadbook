import SwiftUI

struct CultureView: View {
    let trip: Trip

    var body: some View {
        ZStack {
            AppTheme.pageBGGradient.ignoresSafeArea()

            if let culture = trip.culture, !culture.nodes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(culture.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("点击节点查看详情")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "circle.grid.3x3.fill")
                                .font(.system(size: 11))
                                .foregroundColor(PageAccent.culture)
                            Text("\(culture.nodes.count) 节点")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(PageAccent.culture)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(PageAccent.cultureBG)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PageAccent.culture.opacity(0.2), lineWidth: 1))
                    }
                    .padding(.horizontal, AppTheme.padding)
                    .padding(.vertical, 12)
                    .background(AppTheme.cardBG)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AppTheme.border).frame(height: 1)
                    }

                    KnowledgeGraphView(culture: culture)
                }
            } else {
                VStack(spacing: 14) {
                    Text("🏛️").font(.system(size: 52))
                    Text("暂无文化知识内容").font(.subheadline).foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
