import SwiftUI

struct NodeDetailView: View {
    let node: CultureNode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBGGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Hero
                        ZStack {
                            Circle()
                                .fill(PageAccent.cultureBG)
                                .frame(width: 160, height: 160)
                                .blur(radius: 30)

                            VStack(spacing: 14) {
                                Text(node.emoji).font(.system(size: 72))

                                Text(node.name)
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(PageAccent.culture)
                                    .multilineTextAlignment(.center)
                                    .tracking(0.5)

                                if !node.subtitle.isEmpty {
                                    Text(node.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .padding(.horizontal, AppTheme.padding)

                        // 分割线（装饰）
                        HStack {
                            Rectangle().fill(AppTheme.border).frame(height: 1)
                            Text("◆")
                                .font(.caption2)
                                .foregroundColor(PageAccent.culture.opacity(0.4))
                                .padding(.horizontal, 8)
                            Rectangle().fill(AppTheme.border).frame(height: 1)
                        }
                        .padding(.horizontal, AppTheme.padding)

                        // 内容
                        VStack(alignment: .leading, spacing: 16) {
                            Text(node.nodeDescription)
                                .font(.body)
                                .foregroundColor(AppTheme.textPrimary)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let relationType = node.relationType {
                                HStack(spacing: 6) {
                                    Image(systemName: "link.circle.fill")
                                        .foregroundColor(PageAccent.culture)
                                        .font(.caption)
                                    Text(relationType)
                                        .font(.caption.bold())
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(PageAccent.cultureBG)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(PageAccent.culture.opacity(0.2)))
                            }
                        }
                        .padding(AppTheme.padding)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navBG, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
            }
        }
        .presentationBackground(AppTheme.pageBG)
    }
}
