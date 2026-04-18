import SwiftUI

// MARK: - Explore View（AI 灵感引擎）
struct ExploreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: ExploreCategory? = nil
    @State private var appeared = false

    private var ctrl: TripInputController { TripInputController.shared }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBGGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        // 搜索栏
                        searchBar
                            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                            .animation(AppTheme.animSmooth.delay(0.05), value: appeared)

                        // 分类标签
                        categoryRow
                            .opacity(appeared ? 1 : 0)
                            .animation(AppTheme.animSmooth.delay(0.1), value: appeared)

                        // 推荐目的地
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            sectionHeader(
                                icon: "sparkles",
                                title: selectedCategory == nil ? "热门目的地" : (selectedCategory?.label ?? ""),
                                subtitle: "点击直接开始规划"
                            )

                            let filtered = filteredDestinations
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, dest in
                                    DestinationCard(destination: dest) {
                                        ctrl.destination = dest.name
                                        ctrl.chatStep = .idle
                                        dismiss()
                                    }
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 16)
                                    .animation(AppTheme.animSmooth.delay(0.12 + Double(idx) * 0.04), value: appeared)
                                }
                            }
                        }

                        // 主题精选
                        if selectedCategory == nil && searchText.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                sectionHeader(icon: "map", title: "按主题探索", subtitle: nil)
                                ForEach(ExploreCategory.allCases, id: \.self) { cat in
                                    CategoryRow(category: cat) {
                                        withAnimation(AppTheme.animSnappy) {
                                            selectedCategory = cat
                                        }
                                    }
                                    .opacity(appeared ? 1 : 0)
                                    .animation(AppTheme.animSmooth.delay(0.3), value: appeared)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.padding)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("探索")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.navBG, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear { withAnimation { appeared = true } }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textTertiary)
            TextField("搜索目的地…", text: $searchText)
                .font(AppFont.body(15))
                .foregroundColor(AppTheme.textPrimary)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.sm - 1)
        .background(AppTheme.cardBG)
        .cornerRadius(AppTheme.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.borderSubtle, lineWidth: 1))
        .appShadow(AppTheme.softLift())
    }

    // MARK: - Category Row
    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.xs) {
                // 全部
                categoryChip(label: "全部", icon: "globe", isSelected: selectedCategory == nil) {
                    withAnimation(AppTheme.animSnappy) { selectedCategory = nil }
                }
                ForEach(ExploreCategory.allCases, id: \.self) { cat in
                    categoryChip(label: cat.label, icon: cat.icon, isSelected: selectedCategory == cat) {
                        withAnimation(AppTheme.animSnappy) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }

    private func categoryChip(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(AppFont.body(13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(AppTheme.cardBG))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(
                isSelected ? AppTheme.accent.opacity(0.4) : AppTheme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(AccentButtonStyle())
    }

    private func sectionHeader(icon: String, title: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.accent)
            Text(title)
                .font(AppFont.heading(17))
                .foregroundColor(AppTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.caption(11))
                    .foregroundColor(AppTheme.textTertiary)
            }
            Spacer()
        }
    }

    // MARK: - Data
    private var filteredDestinations: [ExploreDestination] {
        var list = selectedCategory == nil
            ? ExploreDestination.all
            : ExploreDestination.all.filter { $0.category == selectedCategory }
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.nameZh.localizedCaseInsensitiveContains(searchText) ||
                $0.tagline.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }
}

// MARK: - Destination Card
private struct DestinationCard: View {
    let destination: ExploreDestination
    let onTap: () -> Void
    @State private var pressed = false

    private var accent: DestinationAccent { destinationAccent(for: destination.name) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // 图标区
                ZStack {
                    Rectangle()
                        .fill(accent.bgColor)
                        .frame(height: 90)
                    VStack(spacing: 4) {
                        Text(accent.emoji).font(.system(size: 38))
                        Text(destination.bestSeason)
                            .font(AppFont.caption(9, weight: .medium))
                            .foregroundColor(accent.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(accent.color.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                // 文字区
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(destination.name)
                        .font(AppFont.heading(15))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(destination.tagline)
                        .font(AppFont.caption(11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AppTheme.Spacing.xxs) {
                        ForEach(destination.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(AppFont.caption(9, weight: .medium))
                                .foregroundColor(accent.color)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(accent.color.opacity(0.08))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBG)
            }
            .cornerRadius(AppTheme.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .stroke(AppTheme.borderSubtle, lineWidth: 1)
            )
            .appShadow(AppTheme.softLift())
            .overlay(alignment: .topTrailing) {
                // 左侧彩条
                HStack {
                    Rectangle()
                        .fill(accent.color)
                        .frame(width: 3)
                        .cornerRadius(1.5, corners: [.topLeft, .bottomLeft])
                    Spacer()
                }
            }
        }
        .buttonStyle(TripCardPressStyle())
    }
}

// MARK: - Category Row
private struct CategoryRow: View {
    let category: ExploreCategory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(category.bgColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(category.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.label)
                        .font(AppFont.body(15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(category.description)
                        .font(AppFont.caption(12))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(AppTheme.Spacing.sm)
            .appCard()
        }
        .buttonStyle(AccentButtonStyle())
    }
}

// MARK: - Data Models
enum ExploreCategory: String, CaseIterable {
    case culture    = "文化古迹"
    case nature     = "自然风光"
    case city       = "都市体验"
    case beach      = "海岛度假"
    case adventure  = "户外探险"
    case food       = "美食之旅"

    var label: String { rawValue }
    var icon: String {
        switch self {
        case .culture:   return "building.columns"
        case .nature:    return "mountain.2"
        case .city:      return "building.2"
        case .beach:     return "water.waves"
        case .adventure: return "figure.hiking"
        case .food:      return "fork.knife"
        }
    }
    var color: Color {
        switch self {
        case .culture:   return Color(hex: "#b87320")
        case .nature:    return Color(hex: "#2a7a4a")
        case .city:      return Color(hex: "#3b5fc0")
        case .beach:     return Color(hex: "#1a6090")
        case .adventure: return Color(hex: "#c96442")
        case .food:      return Color(hex: "#c04060")
        }
    }
    var bgColor: Color {
        switch self {
        case .culture:   return Color(hex: "#fdf5e8")
        case .nature:    return Color(hex: "#e8f5ee")
        case .city:      return Color(hex: "#eef2ff")
        case .beach:     return Color(hex: "#e8f4fb")
        case .adventure: return Color(hex: "#fdf0eb")
        case .food:      return Color(hex: "#fdf0f3")
        }
    }
    var description: String {
        switch self {
        case .culture:   return "古迹、博物馆、历史遗址"
        case .nature:    return "国家公园、山川、极光"
        case .city:      return "建筑、购物、夜生活"
        case .beach:     return "热带岛屿、潜水、日落"
        case .adventure: return "徒步、攀岩、野生动物"
        case .food:      return "米其林、街头小吃、市场"
        }
    }
}

struct ExploreDestination: Identifiable {
    let id = UUID()
    let name: String
    let nameZh: String
    let tagline: String
    let category: ExploreCategory
    let bestSeason: String
    let tags: [String]

    static let all: [ExploreDestination] = [
        .init(name: "Egypt", nameZh: "埃及", tagline: "法老的王国，尼罗河的恩赐", category: .culture, bestSeason: "10–4月", tags: ["金字塔", "神话", "沙漠"]),
        .init(name: "Japan", nameZh: "日本", tagline: "传统与现代的极致融合", category: .culture, bestSeason: "3–5月", tags: ["文化", "美食", "寺庙"]),
        .init(name: "Greece", nameZh: "希腊", tagline: "爱琴海边的文明摇篮", category: .culture, bestSeason: "5–10月", tags: ["古迹", "地中海", "神话"]),
        .init(name: "Hanoi", nameZh: "河内", tagline: "千年古都的街头慢生活", category: .city, bestSeason: "10–4月", tags: ["街食", "法式", "古镇"]),
        .init(name: "Iceland", nameZh: "冰岛", tagline: "极光与火山的奇异国度", category: .nature, bestSeason: "9–3月", tags: ["极光", "冰川", "温泉"]),
        .init(name: "Maldives", nameZh: "马尔代夫", tagline: "世界上最后的净土", category: .beach, bestSeason: "11–4月", tags: ["潜水", "水上屋", "珊瑚"]),
        .init(name: "Peru", nameZh: "秘鲁", tagline: "印加帝国的神秘遗迹", category: .adventure, bestSeason: "5–9月", tags: ["马丘比丘", "徒步", "印加"]),
        .init(name: "Italy", nameZh: "意大利", tagline: "文艺复兴的美食天堂", category: .food, bestSeason: "4–6月", tags: ["美食", "艺术", "古迹"]),
        .init(name: "Thailand", nameZh: "泰国", tagline: "微笑之国的佛教净土", category: .culture, bestSeason: "11–3月", tags: ["寺庙", "美食", "海岛"]),
        .init(name: "Norway", nameZh: "挪威", tagline: "峡湾与极夜的北欧传说", category: .nature, bestSeason: "6–8月", tags: ["峡湾", "极光", "徒步"]),
        .init(name: "Bali", nameZh: "巴厘岛", tagline: "神明之岛的晨钟暮鼓", category: .beach, bestSeason: "4–10月", tags: ["冲浪", "寺庙", "稻田"]),
        .init(name: "Morocco", nameZh: "摩洛哥", tagline: "撒哈拉边的千年迷宫", category: .adventure, bestSeason: "3–5月", tags: ["沙漠", "市集", "蓝城"]),
    ]
}
