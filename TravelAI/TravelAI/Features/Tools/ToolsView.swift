import SwiftUI

struct ToolsView: View {
    let trip: Trip

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // SOS Section
                    if !trip.sosContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("SOS 紧急联系", icon: "sos")

                            Text("紧急情况请拨打以下电话。点击号码可直接拨打。")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal, AppTheme.padding)
                                .padding(.vertical, 8)

                            ForEach(trip.sosContacts.sorted { $0.sortIndex < $1.sortIndex }, id: \.title) { contact in
                                Button {
                                    let clean = contact.phone
                                        .replacingOccurrences(of: "-", with: "")
                                        .replacingOccurrences(of: " ", with: "")
                                        .replacingOccurrences(of: "+", with: "00")
                                    if let url = URL(string: "tel://\(clean)") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(contact.emoji)
                                            .font(.title2)
                                            .frame(width: 36)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(contact.title)
                                                .font(.subheadline.bold())
                                                .foregroundColor(AppTheme.textPrimary)
                                            Text(contact.subtitle)
                                                .font(.caption)
                                                .foregroundColor(AppTheme.textSecondary)
                                        }
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Text(contact.phone)
                                                .font(.subheadline.bold())
                                                .foregroundColor(AppTheme.gold)
                                            Image(systemName: "phone.fill")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.gold)
                                        }
                                    }
                                    .padding(.horizontal, AppTheme.padding)
                                    .padding(.vertical, 12)
                                }
                                Divider()
                                    .background(AppTheme.border)
                                    .padding(.leading, AppTheme.padding)
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cardRadius)
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border))
                    }

                    // Tips Section
                    if !trip.tips.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("旅行贴士", icon: "lightbulb.fill")

                            ForEach(Array(trip.tips.sorted { $0.sortIndex < $1.sortIndex }.enumerated()), id: \.offset) { _, tip in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("◆")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.gold)
                                        .padding(.top, 3)
                                    Text(tip.content)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(.horizontal, AppTheme.padding)
                                .padding(.vertical, 10)
                                Divider()
                                    .background(AppTheme.border)
                                    .padding(.leading, AppTheme.padding)
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cardRadius)
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border))
                    }

                    // Empty state
                    if trip.sosContacts.isEmpty && trip.tips.isEmpty {
                        VStack(spacing: 12) {
                            Text("🧰")
                                .font(.system(size: 48))
                            Text("暂无工具数据")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(AppTheme.padding)
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.gold)
                .font(.caption.bold())
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(AppTheme.gold)
                .tracking(1.5)
        }
        .padding(.horizontal, AppTheme.padding)
        .padding(.vertical, 10)
    }
}
