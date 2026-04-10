import SwiftUI

struct DayCalendarView: View {
    let days: [TripDay]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                    Button {
                        selectedIndex = idx
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayEmoji(for: day))
                                .font(.title2)
                            Text(dayNumber(for: day))
                                .font(.headline)
                                .foregroundColor(idx == selectedIndex ? .black : AppTheme.gold)
                            Text(weekday(for: day))
                                .font(.caption2)
                                .foregroundColor(idx == selectedIndex ? .black.opacity(0.7) : AppTheme.textSecondary)
                        }
                        .frame(width: 56, height: 72)
                        .background(idx == selectedIndex ? AppTheme.gold : AppTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                    }
                }
            }
            .padding(.horizontal, AppTheme.padding)
        }
    }

    private func dayNumber(for day: TripDay) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: day.date)
    }

    private func weekday(for day: TripDay) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: day.date).uppercased()
    }

    private func dayEmoji(for day: TripDay) -> String {
        let emojis = ["🏛️", "⛵", "🖼️", "🚗", "👑", "🏖️", "🐠"]
        let idx = Calendar.current.ordinality(of: .day, in: .era, for: day.date) ?? 0
        return emojis[idx % emojis.count]
    }
}
