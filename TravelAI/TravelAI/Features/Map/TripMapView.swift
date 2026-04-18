import SwiftUI
import MapKit

struct TripMapView: View {
    let trip: Trip
    @State private var vm = TripMapViewModel()

    var body: some View {
        ZStack {
            AppTheme.pageBGGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                let days = trip.days.sorted { $0.sortIndex < $1.sortIndex }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Array(days.enumerated()), id: \.offset) { idx, _ in
                            let selected = vm.selectedDayIndex == idx
                            Button("Day \(idx + 1)") { vm.selectedDayIndex = idx }
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(selected ? PageAccent.map : AppTheme.cardBG)
                                .foregroundColor(selected ? .white : AppTheme.textSecondary)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(
                                    selected ? PageAccent.map.opacity(0.5) : AppTheme.border, lineWidth: 1))
                                .shadow(color: selected ? PageAccent.map.opacity(0.25) : .clear, radius: 6)
                                .animation(AppTheme.animSnappy, value: selected)
                        }
                    }
                    .padding(.horizontal, AppTheme.padding).padding(.vertical, 10)
                }
                .background(AppTheme.cardBG)
                .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.border).frame(height: 1) }

                if days.isEmpty {
                    emptyState
                } else {
                    let events = vm.eventsForDay(vm.selectedDayIndex, in: trip)
                    let coords = vm.polylineCoordinates(for: events)

                    Map {
                        if coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(PageAccent.map, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                        }
                        ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                            if let lat = event.latitude, let lng = event.longitude {
                                Annotation(event.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                                    Button { vm.selectedAnnotation = event } label: {
                                        ZStack {
                                            Circle().fill(PageAccent.map).frame(width: 30, height: 30)
                                                .shadow(color: PageAccent.map.opacity(0.35), radius: 5)
                                            Text("\(idx + 1)")
                                                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
                }
            }
        }
        .sheet(item: $vm.selectedAnnotation) { event in
            EventLocationCard(event: event).presentationDetents([.fraction(0.3)])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🗺️").font(.system(size: 48))
            Text("暂无地图数据").font(.subheadline).foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EventLocationCard: View {
    let event: TripEvent

    var body: some View {
        ZStack {
            AppTheme.pageBG.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(PageAccent.mapBG).frame(width: 38, height: 38)
                            .overlay(Circle().stroke(PageAccent.map.opacity(0.2), lineWidth: 1))
                        Text("📍").font(.system(size: 18))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title).font(.system(size: 15, weight: .bold)).foregroundColor(AppTheme.textPrimary)
                        Text(event.time).font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
                    }
                }
                if !event.locationName.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 12)).foregroundColor(PageAccent.map)
                        Text(event.locationName).font(.system(size: 13)).foregroundColor(AppTheme.textSecondary)
                    }
                }
                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.system(size: 12)).foregroundColor(AppTheme.textTertiary).lineLimit(2)
                }
                Button {
                    guard let lat = event.latitude, let lng = event.longitude else { return }
                    if let url = URL(string: "maps://?daddr=\(lat),\(lng)&dirflg=d") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill").font(.system(size: 13))
                        Text("在 Apple Maps 中导航").font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(PageAccent.map)
                    .foregroundColor(.white)
                    .cornerRadius(AppTheme.cardRadiusSmall)
                    .shadow(color: PageAccent.map.opacity(0.25), radius: 6, y: 2)
                }
            }
            .padding(AppTheme.padding)
        }
    }
}
