import SwiftUI

struct TimelineView: View {
    let day: TripDay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Day header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day \(day.sortIndex + 1) · \(weekday(for: day.date))")
                            .font(.caption)
                            .foregroundColor(AppTheme.gold)
                        Text(day.title)
                            .font(.title2.bold())
                            .foregroundColor(AppTheme.textPrimary)
                        Text(dateText(for: day.date))
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(AppTheme.padding)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cardRadius)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border))
                .padding(.horizontal, AppTheme.padding)
                .padding(.top, 12)

                // Events timeline
                let sortedEvents = day.events.sorted { $0.sortIndex < $1.sortIndex }
                ForEach(Array(sortedEvents.enumerated()), id: \.offset) { idx, event in
                    HStack(alignment: .top, spacing: 12) {
                        // Time column
                        VStack(spacing: 0) {
                            Text(event.time)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(width: 44, alignment: .trailing)

                            if idx < sortedEvents.count - 1 {
                                Rectangle()
                                    .fill(AppTheme.border)
                                    .frame(width: 1, height: 40)
                                    .padding(.top, 4)
                            }
                        }

                        // Dot
                        Circle()
                            .fill(eventColor(for: event.eventType))
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)

                        // Content
                        VStack(alignment: .leading, spacing: 2) {
                            Text(eventEmoji(for: event.eventType) + " " + event.title)
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.textPrimary)
                            if !event.eventDescription.isEmpty {
                                Text(event.eventDescription)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            if !event.locationName.isEmpty {
                                Label(event.locationName, systemImage: "mappin.circle")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, AppTheme.padding)
                    .padding(.top, 12)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func eventColor(for type: String) -> Color {
        switch type {
        case "transport": return .blue
        case "food": return .orange
        case "accommodation": return .purple
        default: return AppTheme.gold
        }
    }

    private func eventEmoji(for type: String) -> String {
        switch type {
        case "transport": return "✈️"
        case "food": return "🍽️"
        case "accommodation": return "🏨"
        default: return "🏛️"
        }
    }

    private func weekday(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: date)
    }

    private func dateText(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd"
        return fmt.string(from: date)
    }
}
