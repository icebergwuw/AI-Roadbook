import SwiftUI
import SwiftData

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    let trip: Trip
    let dayIndex: Int?

    private var items: [ChecklistItem] {
        trip.checklist
            .filter { $0.dayIndex == dayIndex }
            .sorted { !$0.isCompleted && $1.isCompleted }
    }

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(dayIndex == nil ? "GLOBAL CHECKLIST" : "DAY CHECKLIST")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.gold)
                    .tracking(2)
                    .padding(.horizontal, AppTheme.padding)
                    .padding(.vertical, 10)

                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Button {
                            item.isCompleted.toggle()
                            try? modelContext.save()
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundColor(item.isCompleted ? AppTheme.gold : AppTheme.textSecondary)
                        }
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundColor(item.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)
                            .strikethrough(item.isCompleted)
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.padding)
                    .padding(.vertical, 10)
                    Divider()
                        .background(AppTheme.border)
                        .padding(.leading, AppTheme.padding)
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cardRadius)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border))
        }
    }
}
