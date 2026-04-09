import SwiftUI

struct ToolsView: View {
    let trip: Trip
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            Text("工具")
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
