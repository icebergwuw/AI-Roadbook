import SwiftUI

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    var provinceService: ProvinceHighlightService

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    private var totalUnlocked: Int {
        BadgeLibrary.allBadges.filter { provinceService.visitedProvinceIDs.contains($0.id) }.count
    }
    private var totalCount: Int { BadgeLibrary.allBadges.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        overallProgressCard
                            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                        ForEach(BadgeGroup.allCases) { group in
                            badgeSection(group: group)
                        }
                        Spacer(minLength: 40)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("成就徽章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var overallProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("收集进度")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(totalUnlocked) / \(totalCount)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                CircularProgressView(
                    progress: totalCount > 0 ? Double(totalUnlocked) / Double(totalCount) : 0,
                    size: 60
                )
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 5)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                                              startPoint: .leading, endPoint: .trailing))
                        .frame(width: totalCount > 0
                               ? geo.size.width * CGFloat(totalUnlocked) / CGFloat(totalCount) : 0,
                               height: 5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: totalUnlocked)
                }
            }
            .frame(height: 5)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "#111111"))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1)))
    }

    @ViewBuilder
    private func badgeSection(group: BadgeGroup) -> some View {
        let badges = BadgeLibrary.badges(for: group)
        let unlockedCount = badges.filter { provinceService.visitedProvinceIDs.contains($0.id) }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(group.flagEmoji).font(.system(size: 20))
                Text(group.displayName).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Text("\(unlockedCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(unlockedCount > 0 ? Color(hex: "#FFD700") : .white.opacity(0.4))
                    Text("/").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.3))
                    Text("\(badges.count)").font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(unlockedCount > 0 ? Color(hex: "#FFD700").opacity(0.15) : Color.white.opacity(0.06))
                    .overlay(Capsule().stroke(unlockedCount > 0 ? Color(hex: "#FFD700").opacity(0.35) : Color.clear, lineWidth: 1)))
            }
            .padding(.horizontal, 20)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(badges.sorted { a, b in
                    let aU = provinceService.visitedProvinceIDs.contains(a.id)
                    let bU = provinceService.visitedProvinceIDs.contains(b.id)
                    if aU != bU { return aU }
                    return a.name < b.name
                }) { badge in
                    let unlocked = provinceService.visitedProvinceIDs.contains(badge.id)
                    VStack(spacing: 5) {
                        BadgeView(badge: badge, isUnlocked: unlocked)
                        Text(badge.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(unlocked ? .white.opacity(0.65) : .white.opacity(0.2))
                            .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: 70)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Circular Progress
private struct CircularProgressView: View {
    let progress: Double
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
            Circle().trim(from: 0, to: progress)
                .stroke(LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}
