import SwiftUI
import MapKit

struct TripMapView: View {
    let trip: Trip
    @State private var vm = TripMapViewModel()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                let days = trip.days.sorted { $0.sortIndex < $1.sortIndex }

                // Day selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(days.enumerated()), id: \.offset) { idx, _ in
                            Button("Day \(idx + 1)") {
                                vm.selectedDayIndex = idx
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(vm.selectedDayIndex == idx ? AppTheme.gold : AppTheme.cardBackground)
                            .foregroundColor(vm.selectedDayIndex == idx ? .black : AppTheme.textSecondary)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
                        }
                    }
                    .padding(AppTheme.padding)
                }
                .background(AppTheme.background)

                if days.isEmpty {
                    emptyState
                } else {
                    let events = vm.eventsForDay(vm.selectedDayIndex, in: trip)
                    let coords = vm.polylineCoordinates(for: events)

                    Map {
                        if coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(AppTheme.gold, lineWidth: 2)
                        }

                        ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                            if let lat = event.latitude, let lng = event.longitude {
                                Annotation(
                                    event.title,
                                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                                ) {
                                    Button {
                                        vm.selectedAnnotation = event
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(AppTheme.gold)
                                                .frame(width: 28, height: 28)
                                                .shadow(color: .black.opacity(0.3), radius: 3)
                                            Text("\(idx + 1)")
                                                .font(.caption.bold())
                                                .foregroundColor(.black)
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
            EventLocationCard(event: event)
                .presentationDetents([.fraction(0.3)])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🗺️")
                .font(.system(size: 48))
            Text("暂无地图数据")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EventLocationCard: View {
    let event: TripEvent

    var body: some View {
        ZStack {
            AppTheme.cardBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text(event.time + " · " + event.title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                if !event.locationName.isEmpty {
                    Label(event.locationName, systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Button {
                    guard let lat = event.latitude, let lng = event.longitude else { return }
                    let urlStr = "maps://?daddr=\(lat),\(lng)&dirflg=d"
                    if let url = URL(string: urlStr) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("在 Apple Maps 中导航", systemImage: "map.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(AppTheme.gold)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            }
            .padding(AppTheme.padding)
        }
    }
}
