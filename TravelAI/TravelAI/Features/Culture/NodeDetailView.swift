import SwiftUI

struct NodeDetailView: View {
    let node: CultureNode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        Text(node.emoji)
                            .font(.system(size: 64))
                            .padding(.top, 8)

                        Text(node.name)
                            .font(.title.bold())
                            .foregroundColor(AppTheme.gold)
                            .multilineTextAlignment(.center)

                        Text(node.subtitle)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)

                        Divider().background(AppTheme.border)

                        Text(node.nodeDescription)
                            .font(.body)
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        if let relationType = node.relationType {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.gold)
                                Text(relationType)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
                        }
                    }
                    .padding(AppTheme.padding)
                }
            }
            .navigationTitle(node.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(AppTheme.gold)
                }
            }
        }
    }
}
