import SwiftUI

struct ItineraryView: View {
    let trip: Trip
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            Text("行程")
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
