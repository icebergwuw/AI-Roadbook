import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    @State private var selectedTab: DetailTab = .itinerary

    enum DetailTab: String, CaseIterable {
        case itinerary = "行程"
        case culture = "文化"
        case map = "地图"
        case chat = "会话"
        case tools = "工具"
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text(trip.destination.uppercased())
                        .font(.largeTitle.bold())
                        .foregroundColor(AppTheme.gold)
                        .tracking(3)
                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Top tab bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Button(tab.rawValue) {
                                selectedTab = tab
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundColor(selectedTab == tab ? AppTheme.gold : AppTheme.textSecondary)
                            .overlay(alignment: .bottom) {
                                if selectedTab == tab {
                                    Rectangle()
                                        .fill(AppTheme.gold)
                                        .frame(height: 2)
                                }
                            }
                        }
                    }
                }
                .background(AppTheme.cardBackground)

                Divider().background(AppTheme.border)

                // Tab content
                Group {
                    switch selectedTab {
                    case .itinerary:
                        ItineraryView(trip: trip)
                    case .culture:
                        CultureView(trip: trip)
                    case .map:
                        TripMapView(trip: trip)
                    case .chat:
                        ChatView(trip: trip)
                    case .tools:
                        ToolsView(trip: trip)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
    }

    private var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        fmt.locale = Locale(identifier: "en_US")
        return "\(fmt.string(from: trip.startDate).uppercased()) — \(fmt.string(from: trip.endDate).uppercased()) \(Calendar.current.component(.year, from: trip.startDate))"
    }
}
