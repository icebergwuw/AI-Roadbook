import SwiftUI
import SwiftData

struct TodayOverviewView: View {
    @Binding var selectedTab: Int
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext

    private var latestTrip: Trip? { trips.first }

    private var todayDay: TripDay? {
        guard let trip = latestTrip else { return nil }
        let calendar = Calendar.current
        return trip.days
            .sorted { $0.sortIndex < $1.sortIndex }
            .first { calendar.isDateInToday($0.date) }
    }

    private var displayDay: TripDay? {
        guard let trip = latestTrip else { return nil }
        return todayDay ?? trip.days.sorted { $0.sortIndex < $1.sortIndex }.first
    }

    private var isTodayActive: Bool { todayDay != nil }

    private var dayIndex: Int {
        guard let trip = latestTrip, let day = displayDay else { return 1 }
        return (trip.days.sorted { $0.sortIndex < $1.sortIndex }.firstIndex(where: { $0.persistentModelID == day.persistentModelID }) ?? 0) + 1
    }

    private var totalDays: Int { latestTrip?.days.count ?? 0 }

    private var todayChecklist: [ChecklistItem] {
        guard let trip = latestTrip, let day = displayDay else { return [] }
        let idx = trip.days.sorted { $0.sortIndex < $1.sortIndex }
            .firstIndex(where: { $0.persistentModelID == day.persistentModelID }) ?? 0
        return trip.checklist.filter { $0.dayIndex == idx }
    }

    private var completedCount: Int { todayChecklist.filter { $0.isCompleted }.count }
    private var totalCount: Int { todayChecklist.count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if let trip = latestTrip, let day = displayDay {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 旅行标题
                            tripHeader(trip: trip, day: day)

                            // 今日行程
                            eventsSection(day: day)

                            // 今日待办
                            if totalCount > 0 {
                                checklistSection()
                            }

                            // 跳转按钮
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                HStack {
                                    Text("查看完整行程")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.background)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(AppTheme.background)
                                }
                                .padding()
                                .background(AppTheme.gold)
                                .cornerRadius(AppTheme.cardRadius)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                    }
                } else {
                    emptyState()
                }
            }
            .navigationTitle("行程")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func tripHeader(trip: Trip, day: TripDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.destination)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.gold)

            HStack(spacing: 8) {
                Text(formattedToday())
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)

                Text("·")
                    .foregroundColor(AppTheme.textSecondary)

                Text("Day \(dayIndex)/\(totalDays)")
                    .font(.subheadline)
                    .foregroundColor(isTodayActive ? AppTheme.gold : AppTheme.textSecondary)

                if !isTodayActive {
                    Text("（旅行未在进行中）")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func eventsSection(day: TripDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日行程")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal)

            let events = day.events.sorted { $0.sortIndex < $1.sortIndex }
            if events.isEmpty {
                Text("暂无行程安排")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.persistentModelID) { idx, event in
                        HStack(alignment: .top, spacing: 12) {
                            // 时间线圆点 + 竖线
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(eventColor(for: event.eventType))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 4)
                                if idx < events.count - 1 {
                                    Rectangle()
                                        .fill(AppTheme.border)
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(event.time)
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text("·")
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text(event.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                if !event.locationName.isEmpty {
                                    Label(event.locationName, systemImage: "mappin")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cardRadius)
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func checklistSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日待办")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(completedCount) / \(totalCount) 完成")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.border)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.gold)
                        .frame(
                            width: totalCount > 0
                                ? geo.size.width * CGFloat(completedCount) / CGFloat(totalCount)
                                : 0,
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardRadius)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func emptyState() -> some View {
        VStack(spacing: 20) {
            Text("🗺️")
                .font(.system(size: 60))
            Text("还没有旅行计划")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)
            Text("创建你的第一个旅行攻略")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            Button {
                selectedTab = 2
            } label: {
                Label("新建旅行", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.background)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.gold)
                    .cornerRadius(AppTheme.cardRadius)
            }
        }
    }

    // MARK: - Helpers

    private func formattedToday() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return "今天 · " + f.string(from: Date())
    }

    private func eventColor(for type: String) -> Color {
        switch type {
        case "transport":     return AppTheme.textSecondary
        case "food":          return AppTheme.goldSecondary
        case "accommodation": return AppTheme.goldSecondary
        default:              return AppTheme.gold  // attraction
        }
    }
}

#Preview {
    TodayOverviewView(selectedTab: .constant(1))
        .modelContainer(for: [Trip.self, TripDay.self, TripEvent.self, ChecklistItem.self])
}
