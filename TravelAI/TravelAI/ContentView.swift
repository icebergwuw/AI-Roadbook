import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Trip.self, TripDay.self, TripEvent.self,
                               Message.self, ChecklistItem.self])
}
