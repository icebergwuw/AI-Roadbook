import MapKit
import Foundation

@Observable
final class TripMapViewModel {
    var selectedDayIndex: Int = 0
    var selectedAnnotation: TripEvent?

    func eventsForDay(_ index: Int, in trip: Trip) -> [TripEvent] {
        let days = trip.days.sorted { $0.sortIndex < $1.sortIndex }
        guard index < days.count else { return [] }
        return days[index].events
            .filter { $0.latitude != nil && $0.longitude != nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    func region(for events: [TripEvent]) -> MKCoordinateRegion {
        guard !events.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 30, longitude: 30),
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
        }
        let lats = events.compactMap { $0.latitude }
        let lngs = events.compactMap { $0.longitude }
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLng = lngs.min()!
        let maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
            longitudeDelta: max((maxLng - minLng) * 1.5, 0.05)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    func polylineCoordinates(for events: [TripEvent]) -> [CLLocationCoordinate2D] {
        events.compactMap { event in
            guard let lat = event.latitude, let lng = event.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
}
