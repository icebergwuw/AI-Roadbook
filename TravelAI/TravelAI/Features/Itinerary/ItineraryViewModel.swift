import Foundation

@Observable
final class ItineraryViewModel {
    var selectedDayIndex: Int = 0

    func selectedDay(in trip: Trip) -> TripDay? {
        let sorted = trip.days.sorted { $0.sortIndex < $1.sortIndex }
        guard selectedDayIndex < sorted.count else { return nil }
        return sorted[selectedDayIndex]
    }

    func sortedDays(in trip: Trip) -> [TripDay] {
        trip.days.sorted { $0.sortIndex < $1.sortIndex }
    }
}
