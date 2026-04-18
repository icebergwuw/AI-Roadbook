import SwiftUI

struct ToolsView: View {
    let trip: Trip

    var body: some View {
        ZStack {
            AppTheme.pageBGGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    if !trip.sosContacts.isEmpty {
                        toolSection(title: "SOS 紧急联系", icon: "sos.circle.fill", accent: AppTheme.red, accentBG: AppTheme.redBG) {
                            VStack(spacing: 0) {
                                HStack(spacing: 5) {
                                    Image(systemName: "info.circle").font(.system(size: 11)).foregroundColor(AppTheme.textTertiary)
                                    Text("紧急情况请拨打以下电话 · 点击可直接拨打")
                                        .font(.system(size: 12)).foregroundColor(AppTheme.textTertiary)
                                }
                                .padding(.horizontal, AppTheme.padding).padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(Array(trip.sosContacts.sorted { $0.sortIndex < $1.sortIndex }.enumerated()), id: \.offset) { idx, contact in
                                    sosRow(contact: contact)
                                    if idx < trip.sosContacts.count - 1 {
                                        Rectangle().fill(AppTheme.borderSubtle).frame(height: 1)
                                            .padding(.leading, AppTheme.padding + 46)
                                    }
                                }
                            }
                        }
                    }

                    if !trip.tips.isEmpty {
                        toolSection(title: "旅行贴士", icon: "lightbulb.fill", accent: PageAccent.tools, accentBG: PageAccent.toolsBG) {
                            VStack(spacing: 0) {
                                ForEach(Array(trip.tips.sorted { $0.sortIndex < $1.sortIndex }.enumerated()), id: \.offset) { idx, tip in
                                    tipRow(tip: tip, index: idx)
                                    if idx < trip.tips.count - 1 {
                                        Rectangle().fill(AppTheme.borderSubtle).frame(height: 1)
                                            .padding(.leading, AppTheme.padding + 28)
                                    }
                                }
                            }
                        }
                    }

                    if trip.sosContacts.isEmpty && trip.tips.isEmpty {
                        VStack(spacing: 12) {
                            Text("🧰").font(.system(size: 48))
                            Text("暂无工具数据").font(.subheadline).foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(AppTheme.padding).padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func toolSection<Content: View>(
        title: String, icon: String, accent: Color, accentBG: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(accent)
                Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundColor(accent).tracking(1.2)
            }
            .padding(.horizontal, AppTheme.padding).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accentBG)

            Rectangle().fill(accent.opacity(0.15)).frame(height: 1)
            content()
        }
        .appCard(accent: accent)
    }

    private func sosRow(contact: SOSContact) -> some View {
        Button {
            let clean = contact.phone
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "+", with: "00")
            if let url = URL(string: "tel://\(clean)") { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.redBG).frame(width: 40, height: 40)
                        .overlay(Circle().stroke(AppTheme.red.opacity(0.12), lineWidth: 1))
                    Text(contact.emoji).font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.title).font(.system(size: 14, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
                    Text(contact.subtitle).font(.system(size: 12)).foregroundColor(AppTheme.textSecondary).lineLimit(1)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(contact.phone).font(.system(size: 14, weight: .bold)).foregroundColor(AppTheme.red)
                    Image(systemName: "phone.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.red)
                }
            }
            .padding(.horizontal, AppTheme.padding).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tipRow(tip: Tip, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(PageAccent.toolsBG).frame(width: 26, height: 26)
                    .overlay(Circle().stroke(PageAccent.tools.opacity(0.2), lineWidth: 1))
                Text("\(index + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(PageAccent.tools)
            }
            Text(tip.content)
                .font(.system(size: 14)).foregroundColor(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
            Spacer()
        }
        .padding(.horizontal, AppTheme.padding).padding(.vertical, 11)
    }
}
