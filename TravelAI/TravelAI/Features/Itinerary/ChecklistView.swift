import SwiftUI
import SwiftData

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    let trip: Trip
    let dayIndex: Int?

    private var items: [ChecklistItem] {
        trip.checklist
            .filter { $0.dayIndex == dayIndex }
            .sorted { (!$0.isCompleted && $1.isCompleted) || ($0.isCompleted == $1.isCompleted && $0.title < $1.title) }
    }
    private var completedCount: Int { items.filter { $0.isCompleted }.count }

    var body: some View {
        if items.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Label(
                        dayIndex == nil ? "行前清单" : "当日清单",
                        systemImage: dayIndex == nil ? "checklist" : "list.bullet.clipboard"
                    )
                    .font(.caption.bold())
                    .foregroundColor(PageAccent.itinerary)
                    .tracking(0.5)
                    Spacer()
                    Text("\(completedCount)/\(items.count)")
                        .font(.caption2.bold())
                        .foregroundColor(completedCount == items.count ? AppTheme.teal : AppTheme.textTertiary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(completedCount == items.count ? AppTheme.tealBG : AppTheme.sectionBG)
                        .cornerRadius(8)
                }
                .padding(.horizontal, AppTheme.padding)
                .padding(.vertical, 12)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(AppTheme.border.opacity(0.5)).frame(height: 2)
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [PageAccent.itinerary, Color(hex: "#A05808")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(
                                width: items.isEmpty ? 0 : geo.size.width * CGFloat(completedCount) / CGFloat(items.count),
                                height: 2
                            )
                            .animation(AppTheme.animSmooth, value: completedCount)
                    }
                }
                .frame(height: 2)

                ForEach(items) { item in
                    ChecklistRow(item: item) {
                        withAnimation(AppTheme.animSnappy) {
                            item.isCompleted.toggle()
                            try? modelContext.save()
                        }
                    }
                    if item.id != items.last?.id {
                        Rectangle().fill(AppTheme.borderSubtle).frame(height: 1)
                            .padding(.leading, AppTheme.padding + 36)
                    }
                }
            }
            .appCard()
        }
    }
}

private struct ChecklistRow: View {
    let item: ChecklistItem
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(item.isCompleted ? PageAccent.itinerary : AppTheme.borderStrong, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if item.isCompleted {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(
                                colors: [PageAccent.itinerary, Color(hex: "#A05808")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.subheadline)
                .foregroundColor(item.isCompleted ? AppTheme.textTertiary : AppTheme.textPrimary)
                .strikethrough(item.isCompleted, color: AppTheme.textTertiary)
                .animation(AppTheme.animSmooth, value: item.isCompleted)
            Spacer()
        }
        .padding(.horizontal, AppTheme.padding)
        .padding(.vertical, 11)
    }
}
