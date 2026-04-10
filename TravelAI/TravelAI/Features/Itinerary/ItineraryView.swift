import SwiftUI

struct ItineraryView: View {
    let trip: Trip
    @State private var vm = ItineraryViewModel()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                let days = vm.sortedDays(in: trip)

                if days.isEmpty {
                    emptyState
                } else {
                    DayCalendarView(
                        days: days,
                        selectedIndex: $vm.selectedDayIndex
                    )
                    .padding(.vertical, 12)
                    .background(AppTheme.background)

                    Divider().background(AppTheme.border)

                    ScrollView {
                        VStack(spacing: 16) {
                            if let day = vm.selectedDay(in: trip) {
                                TimelineView(day: day)
                                ChecklistView(trip: trip, dayIndex: vm.selectedDayIndex)
                                    .padding(.horizontal, AppTheme.padding)
                                ChecklistView(trip: trip, dayIndex: nil)
                                    .padding(.horizontal, AppTheme.padding)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📅")
                .font(.system(size: 48))
            Text("暂无行程数据")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
