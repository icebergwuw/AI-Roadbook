import SwiftUI

struct TripMapView: View {
    let trip: Trip
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            Text("地图")
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
