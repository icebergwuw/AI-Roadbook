import SwiftUI

struct TimelineView: View {
    let day: TripDay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dayHeader
                .padding(.horizontal, AppTheme.padding)
                .padding(.top, 14)
                .padding(.bottom, 14)

            let events = day.events.sorted { $0.sortIndex < $1.sortIndex }
            ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                EventRow(event: event, isLast: idx == events.count - 1)
            }
        }
    }

    private var dayHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [PageAccent.itinerary, Color(hex: "#A05808")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 46, height: 46)
                    .shadow(color: PageAccent.itinerary.opacity(0.3), radius: 6, y: 2)
                Text("\(day.sortIndex + 1)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(weekday(for: day.date))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(PageAccent.itinerary)
                        .tracking(1)
                    Text("·").foregroundColor(AppTheme.border)
                    Text(dateText(for: day.date))
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Text(day.title)
                    .font(AppFont.headingSmall(15))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(day.events.count) 项")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(PageAccent.itinerary)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(PageAccent.itineraryBG)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PageAccent.itinerary.opacity(0.2), lineWidth: 1))
        }
        .padding(14)
        .appCard(accent: PageAccent.itinerary)
    }

    private func weekday(for date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE"; fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: date).uppercased()
    }
    private func dateText(for date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "M月d日"; fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: date)
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: TripEvent
    let isLast: Bool
    @State private var expanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 时间列
            VStack(spacing: 0) {
                Text(event.time)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(width: 44, alignment: .trailing)
                    .padding(.top, 3)
                if !isLast {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 6)
                }
            }
            .frame(width: 44)

            // 节点圆点
            ZStack {
                Circle().fill(AppTheme.cardBG).frame(width: 16, height: 16)
                Circle().fill(eventColor(for: event.eventType)).frame(width: 9, height: 9)
                    .shadow(color: eventColor(for: event.eventType).opacity(0.4), radius: 3)
            }
            .padding(.top, 2).padding(.horizontal, 10)

            // 内容卡（亮色）
            Button {
                withAnimation(AppTheme.animSnappy) { expanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(eventEmoji(for: event.eventType)).font(.system(size: 13))
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    if expanded {
                        VStack(alignment: .leading, spacing: 5) {
                            if !event.eventDescription.isEmpty {
                                Text(event.eventDescription)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)
                                    .padding(.top, 5)
                            }
                            if !event.locationName.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(PageAccent.itinerary)
                                    Text(event.locationName)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(expanded ? PageAccent.itineraryBG : AppTheme.cardBG)
                .cornerRadius(AppTheme.cardRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadiusSmall)
                        .stroke(
                            expanded ? eventColor(for: event.eventType).opacity(0.35) : AppTheme.border,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, AppTheme.padding)
            .padding(.bottom, isLast ? 4 : 10)
        }
        .padding(.leading, AppTheme.padding)
    }

    private func eventColor(for type: String) -> Color { TravelAI.eventColor(for: type) }
    private func eventEmoji(for type: String) -> String { TravelAI.eventEmoji(for: type) }
}
