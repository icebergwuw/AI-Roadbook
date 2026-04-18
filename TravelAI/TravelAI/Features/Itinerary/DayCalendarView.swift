import SwiftUI

struct DayCalendarView: View {
    let days: [TripDay]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                        DayPill(day: day, index: idx, isSelected: idx == selectedIndex) {
                            withAnimation(AppTheme.animSnappy) { selectedIndex = idx }
                        }
                        .id(idx)
                    }
                }
                .padding(.horizontal, AppTheme.padding)
                .padding(.vertical, 2)
            }
            .onChange(of: selectedIndex) { _, newIdx in
                withAnimation(AppTheme.animSmooth) {
                    proxy.scrollTo(newIdx, anchor: .center)
                }
            }
            .onAppear {
                // 初始定位到当前选中项
                proxy.scrollTo(selectedIndex, anchor: .center)
            }
        }
    }
}

private struct DayPill: View {
    let day: TripDay
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xxs + 1) {
                Text(dayEmoji)
                    .font(.system(size: 17))

                Text(dayNumber)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)

                Text(weekday)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.75) : AppTheme.textTertiary)
                    .tracking(0.8)
            }
            .frame(width: 58, height: 76)
            .background(
                isSelected
                ? AnyShapeStyle(LinearGradient(
                    colors: [AppTheme.accent, Color(hex: "#a04030")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                  ))
                : AnyShapeStyle(AppTheme.cardBG)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.4) : AppTheme.borderSubtle, lineWidth: 1)
            )
            .shadow(
                color: isSelected ? AppTheme.accent.opacity(0.28) : Color.black.opacity(0.04),
                radius: isSelected ? 8 : 3, x: 0, y: 2
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(AppTheme.animSnappy, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var dayNumber: String {
        let fmt = DateFormatter(); fmt.dateFormat = "d"
        return fmt.string(from: day.date)
    }
    private var weekday: String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: day.date).uppercased()
    }
    private var dayEmoji: String {
        ["🏛️","⛵","🖼️","🚗","👑","🏖️","🐠","🌄","🦁","🎭"][index % 10]
    }
}
