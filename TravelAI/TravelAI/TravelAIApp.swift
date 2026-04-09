import SwiftUI
import SwiftData

@main
struct TravelAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    Trip.self,
                    TripDay.self,
                    TripEvent.self,
                    CultureData.self,
                    CultureNode.self,
                    ChecklistItem.self,
                    Message.self,
                    SOSContact.self,
                    Tip.self
                ])
        }
    }
}
