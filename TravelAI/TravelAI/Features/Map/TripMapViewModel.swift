import MapKit
import Foundation

@Observable
final class TripMapViewModel {
    var selectedDayIndex: Int = 0
    var selectedAnnotation: TripEvent?

    // 真实路线：key = dayIndex，value = 各段路线坐标（已拼接）
    var realRoutesByDay: [Int: [[CLLocationCoordinate2D]]] = [:]
    // 加载状态
    var loadingRouteForDay: Int? = nil

    // 切换 Day 时触发路线加载
    func loadRealRoutes(for dayIndex: Int, in trip: Trip) {
        // 已有缓存或正在加载则跳过
        guard realRoutesByDay[dayIndex] == nil,
              loadingRouteForDay != dayIndex else { return }

        let events = eventsForDay(dayIndex, in: trip)
        guard events.count >= 2 else { return }

        loadingRouteForDay = dayIndex

        Task {
            let segments = await fetchRoutes(for: events)
            await MainActor.run {
                realRoutesByDay[dayIndex] = segments
                if loadingRouteForDay == dayIndex { loadingRouteForDay = nil }
            }
        }
    }

    /// 串行请求每段路线，失败时用直线降级，返回每段的坐标数组
    private func fetchRoutes(for events: [TripEvent]) async -> [[CLLocationCoordinate2D]] {
        var segments: [[CLLocationCoordinate2D]] = []

        for i in 0..<(events.count - 1) {
            guard
                let lat1 = events[i].latitude,   let lng1 = events[i].longitude,
                let lat2 = events[i+1].latitude, let lng2 = events[i+1].longitude
            else { continue }

            let from = CLLocationCoordinate2D(latitude: lat1, longitude: lng1)
            let to   = CLLocationCoordinate2D(latitude: lat2, longitude: lng2)

            // 两点距离超过 50km 则不请求路线（跨城，直线更合理）
            let dist = distance(from, to)
            if dist > 50_000 {
                segments.append([from, to])
                continue
            }

            let request = MKDirections.Request()
            request.source      = MKMapItem(placemark: MKPlacemark(coordinate: from))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
            request.transportType = dist < 3_000 ? .walking : .automobile

            if let coords = try? await MKDirections(request: request).calculate()
                .routes.first.map({ extractCoords($0) }), !coords.isEmpty {
                segments.append(coords)
            } else {
                // 降级：直线
                segments.append([from, to])
            }
        }
        return segments
    }

    private func extractCoords(_ route: MKRoute) -> [CLLocationCoordinate2D] {
        let poly = route.polyline
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: poly.pointCount)
        poly.getCoordinates(&coords, range: NSRange(location: 0, length: poly.pointCount))
        return coords
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6_371_000.0
        let lat1 = a.latitude  * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let dLat = (b.latitude  - a.latitude)  * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let x = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return R * 2 * atan2(sqrt(x), sqrt(1-x))
    }

    // MARK: - 获取当前 Day 的折线坐标（优先真实路线，否则直线）
    func routePolylines(for dayIndex: Int, events: [TripEvent]) -> [[CLLocationCoordinate2D]] {
        if let real = realRoutesByDay[dayIndex], !real.isEmpty {
            return real
        }
        // 降级：直线
        let pts = events.compactMap { e -> CLLocationCoordinate2D? in
            guard let lat = e.latitude, let lng = e.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard pts.count >= 2 else { return [] }
        return [pts]
    }

    func eventsForDay(_ index: Int, in trip: Trip) -> [TripEvent] {
        let days = trip.days.sorted { $0.sortIndex < $1.sortIndex }
        guard index < days.count else { return [] }
        return days[index].events
            .filter { $0.latitude != nil && $0.longitude != nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    func polylineCoordinates(for events: [TripEvent]) -> [CLLocationCoordinate2D] {
        events.compactMap { event in
            guard let lat = event.latitude, let lng = event.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
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
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.05),
            longitudeDelta: max((lngs.max()! - lngs.min()!) * 1.5, 0.05)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
