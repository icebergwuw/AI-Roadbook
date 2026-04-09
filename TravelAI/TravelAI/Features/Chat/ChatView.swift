import SwiftUI

struct ChatView: View {
    let trip: Trip
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            Text("会话")
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
