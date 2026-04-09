import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var showNewTrip = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if trips.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(trips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip)) {
                                    TripCard(trip: trip)
                                }
                            }
                        }
                        .padding(AppTheme.padding)
                    }
                }
            }
            .navigationTitle("我的旅行")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewTrip = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
            .sheet(isPresented: $showNewTrip) {
                NewTripView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🗺️")
                .font(.system(size: 64))
            Text("还没有旅行计划")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("点击右上角 + 开始规划")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

struct TripCard: View {
    let trip: Trip

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.destination.uppercased())
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.gold)
                    .tracking(2)

                Text(dateRangeText)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                Text("\(trip.days.count) 天行程")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.border)
        }
        .padding(AppTheme.padding)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        fmt.locale = Locale(identifier: "en_US")
        return "\(fmt.string(from: trip.startDate)) — \(fmt.string(from: trip.endDate)) \(Calendar.current.component(.year, from: trip.startDate))"
    }
}
