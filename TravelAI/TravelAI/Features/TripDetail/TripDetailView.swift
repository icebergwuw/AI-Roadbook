import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @State private var selectedTab: DetailTab = .itinerary
    @State private var appeared = false

    enum DetailTab: String, CaseIterable {
        case itinerary = "行程"
        case culture   = "文化"
        case map       = "地图"
        case chat      = "会话"
        case tools     = "工具"

        var icon: String {
            switch self {
            case .itinerary: return "calendar"
            case .culture:   return "globe.asia.australia"
            case .map:       return "map"
            case .chat:      return "bubble.left.and.bubble.right"
            case .tools:     return "wrench.and.screwdriver"
            }
        }
        var accent: Color {
            switch self {
            case .itinerary: return PageAccent.itinerary
            case .culture:   return PageAccent.culture
            case .map:       return PageAccent.map
            case .chat:      return PageAccent.chat
            case .tools:     return PageAccent.tools
            }
        }
        var accentBG: Color {
            switch self {
            case .itinerary: return PageAccent.itineraryBG
            case .culture:   return PageAccent.cultureBG
            case .map:       return PageAccent.mapBG
            case .chat:      return PageAccent.chatBG
            case .tools:     return PageAccent.toolsBG
            }
        }
    }

    private var tripAccent: DestinationAccent { destinationAccent(for: trip.destination) }

    var body: some View {
        ZStack {
            AppTheme.pageBGGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                heroHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -8)
                    .animation(AppTheme.animSmooth.delay(0.04), value: appeared)

                tabBar
                    .opacity(appeared ? 1 : 0)
                    .animation(AppTheme.animSmooth.delay(0.1), value: appeared)

                Group {
                    switch selectedTab {
                    case .itinerary: ItineraryView(trip: trip)
                    case .culture:   CultureView(trip: trip)
                    case .map:       TripMapView(trip: trip)
                    case .chat:      ChatView(trip: trip)
                    case .tools:     ToolsView(trip: trip)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .id(selectedTab)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navBG, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear { withAnimation { appeared = true } }
    }

    // MARK: - Hero Header（亮色系，目的地 accent 渐变作为顶部装饰条）
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            AppTheme.cardBG

            // 顶部彩色装饰条（目的地主题色）
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [tripAccent.color.opacity(0.25), tripAccent.color.opacity(0.05)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 4)
                Spacer()
            }

            // 右侧装饰圆
            GeometryReader { geo in
                Circle()
                    .fill(tripAccent.color.opacity(0.08))
                    .frame(width: 100)
                    .offset(x: geo.size.width - 60, y: -20)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tripAccent.emoji).font(.system(size: 20))
                        Text(trip.destination)
                            .font(AppFont.heading(20))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    HStack(spacing: 6) {
                        Text(dateRangeText)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("·")
                            .foregroundColor(AppTheme.border)
                        Text("\(trip.days.count) 天")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(tripAccent.color)
                    }
                }
                .padding(.leading, AppTheme.padding)
                .padding(.bottom, 12)
                .padding(.top, 16)

                Spacer()

                // 当前 tab 指示器
                HStack(spacing: 5) {
                    Image(systemName: selectedTab.icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(selectedTab.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(selectedTab.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedTab.accentBG)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selectedTab.accent.opacity(0.25), lineWidth: 1))
                .padding(.trailing, AppTheme.padding)
                .padding(.bottom, 12)
                .animation(AppTheme.animSnappy, value: selectedTab)
            }
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
        .appShadow(AppTheme.cardShadow())
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .background(AppTheme.cardBG)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    private func tabButton(_ tab: DetailTab) -> some View {
        let selected = selectedTab == tab
        return Button {
            withAnimation(AppTheme.animSnappy) { selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? tab.accent : AppTheme.textTertiary)
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: selected ? .bold : .medium))
                    .foregroundColor(selected ? tab.accent : AppTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selected ? tab.accentBG : Color.clear)
            .cornerRadius(0)
            .overlay(alignment: .bottom) {
                if selected {
                    Rectangle()
                        .fill(tab.accent)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(AppTheme.animSnappy, value: selected)
    }

    private var dateRangeText: String {
        let fmt = DateFormatter(); fmt.dateFormat = "d MMM"; fmt.locale = Locale(identifier: "en_US")
        return "\(fmt.string(from: trip.startDate).uppercased()) — \(fmt.string(from: trip.endDate).uppercased()) \(Calendar.current.component(.year, from: trip.startDate))"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Trip.self, TripDay.self, TripEvent.self, CultureData.self, CultureNode.self,
            ChecklistItem.self, Message.self, SOSContact.self, Tip.self,
        configurations: config
    )
    let trip = MockData.makeMockTrip(in: container.mainContext)
    return NavigationStack {
        TripDetailView(trip: trip)
    }
    .modelContainer(container)
}
