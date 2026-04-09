import SwiftUI

struct CultureView: View {
    let trip: Trip
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            Text("文化")
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
