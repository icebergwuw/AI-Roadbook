import SwiftUI
import MapKit
import CoreLocation

/// 首页主地图（无动画状态）
/// - 使用 MKMapView，复用 PhotoPointOverlay/PhotoPointRenderer，渲染真实GPS照片光点
/// - 支持省份高亮、用户位置标注、飞行结束后残留轨迹
struct MainMapView: UIViewRepresentable {

    var photoService: PhotoMemoryService
    var photoLocationCount: Int
    var provinceService: ProvinceHighlightService
    var coordinate: CLLocationCoordinate2D?
    /// 飞行结束后残留的 animator（只读轨迹/标注，不做实时动画）
    var flightAnimator: FlightRouteAnimator?
    /// 外部设置相机（初始化或动画结束后继承位置）
    var initialCamera: MKMapCamera?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
        map.showsUserLocation = false
        map.showsCompass = false
        map.isRotateEnabled = true
        map.isPitchEnabled = true

        let cam = initialCamera ?? MKMapCamera(
            lookingAtCenter: coordinate ?? CLLocationCoordinate2D(latitude: 25, longitude: 110),
            fromDistance: 12_000_000, pitch: 0, heading: 0
        )
        map.setCamera(cam, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.update(map: map, view: self)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MainMapView
        private var lastPhotoCount   = -1
        private var lastRegionCount  = -1
        private var lastFlightPoints = -1
        private var lastAnnCount     = -1
        private var lastUserCoord: CLLocationCoordinate2D?
        private var userAnnotation: UserDotAnnotation?
        private var flightAnnotations: [RoutePin] = []

        init(_ parent: MainMapView) { self.parent = parent }

        func update(map: MKMapView, view: MainMapView) {
            parent = view
            updatePhotoOverlay(map: map, view: view)
            updateProvinceOverlays(map: map, view: view)
            updateUserAnnotation(map: map, view: view)
            updateFlightOverlay(map: map, view: view)
        }

        // MARK: - 照片点
        private func updatePhotoOverlay(map: MKMapView, view: MainMapView) {
            guard view.photoLocationCount != lastPhotoCount else { return }
            map.removeOverlays(map.overlays.filter { $0 is PhotoPointOverlay })
            if view.photoLocationCount > 0 {
                let locs = view.photoService.locations
                DispatchQueue.global(qos: .userInitiated).async {
                    let overlay = PhotoPointOverlay(locations: locs)
                    DispatchQueue.main.async { map.addOverlay(overlay, level: .aboveRoads) }
                }
            }
            lastPhotoCount = view.photoLocationCount
        }

        // MARK: - 省份高亮
        private func updateProvinceOverlays(map: MKMapView, view: MainMapView) {
            let count = view.provinceService.visitedRegions.count
            guard count != lastRegionCount else { return }
            map.removeOverlays(map.overlays.filter { $0 is MKPolygon })
            for region in view.provinceService.visitedRegions {
                for poly in region.polygons {
                    map.addOverlay(MKPolygon(coordinates: poly, count: poly.count),
                                   level: .aboveRoads)
                }
            }
            lastRegionCount = count
        }

        // MARK: - 用户位置
        private func updateUserAnnotation(map: MKMapView, view: MainMapView) {
            guard let coord = view.coordinate else { return }
            let changed = lastUserCoord.map {
                abs($0.latitude  - coord.latitude)  > 0.0001 ||
                abs($0.longitude - coord.longitude) > 0.0001
            } ?? true
            guard changed else { return }
            if let ann = userAnnotation { map.removeAnnotation(ann) }
            let ann = UserDotAnnotation(coordinate: coord)
            map.addAnnotation(ann)
            userAnnotation = ann
            lastUserCoord = coord
        }

        // MARK: - 飞行残留轨迹 + 标注
        private func updateFlightOverlay(map: MKMapView, view: MainMapView) {
            let pts  = view.flightAnimator?.drawnPoints.count  ?? 0
            let anns = view.flightAnimator?.visibleAnnotations.count ?? 0
            guard pts != lastFlightPoints || anns != lastAnnCount else { return }

            // 清除旧的飞行 overlay
            map.removeOverlays(map.overlays.filter { $0 is MKPolyline })
            // 清除旧的飞行标注
            map.removeAnnotations(flightAnnotations)
            flightAnnotations = []

            if let animator = view.flightAnimator, animator.drawnPoints.count > 1 {
                let coords = animator.drawnPoints
                let color  = flightLineUIColor(animator)

                // 主线
                let line = MKPolyline(coordinates: coords, count: coords.count)
                line.title = "flight_main"
                map.addOverlay(line, level: .aboveLabels)

                // 光晕线
                let glow = MKPolyline(coordinates: coords, count: coords.count)
                glow.title = "flight_glow"
                map.addOverlay(glow, level: .aboveLabels)

                // 标注
                for ann in animator.visibleAnnotations {
                    let pin = RoutePin(routeAnnotation: ann)
                    flightAnnotations.append(pin)
                }
                map.addAnnotations(flightAnnotations)
                _ = color // 颜色在 rendererFor 里用
            }
            lastFlightPoints = pts
            lastAnnCount     = anns
        }

        private func flightLineUIColor(_ animator: FlightRouteAnimator) -> UIColor {
            switch animator.currentPhase {
            case .enRoute:             return .white
            case .toHub:               return UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1)
            case .itineraryDay(let d):
                let c: [UIColor] = [
                    UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1),
                    UIColor(red: 0,    green: 0.48, blue: 1,    alpha: 1),
                    UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1),
                    UIColor(red: 1,    green: 0.18, blue: 0.33, alpha: 1),
                    UIColor(red: 1,    green: 0.62, blue: 0.04, alpha: 1),
                    UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1),
                ]
                return c[d % c.count]
            default: return .white
            }
        }

        // MARK: - rendererFor
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let photoOverlay = overlay as? PhotoPointOverlay {
                return PhotoPointRenderer(overlay: photoOverlay)
            }
            if let polygon = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: polygon)
                r.fillColor   = UIColor(red: 0, green: 0.83, blue: 0.67, alpha: 0.22)
                r.strokeColor = UIColor(red: 0, green: 0.83, blue: 0.67, alpha: 0.65)
                r.lineWidth   = 1.0
                return r
            }
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                let animator = parent.flightAnimator
                let color = animator.map { flightLineUIColor($0) } ?? .white
                if polyline.title == "flight_glow" {
                    r.strokeColor = color.withAlphaComponent(0.25)
                    r.lineWidth   = 8
                } else {
                    r.strokeColor = color
                    r.lineWidth   = 2.5
                    if animator?.currentPhase == .enRoute {
                        r.lineDashPattern = [10, 6]
                    }
                }
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - viewFor annotation
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let dot = annotation as? UserDotAnnotation {
                let id = "UserDot"
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: dot, reuseIdentifier: id)
                v.annotation = annotation
                v.canShowCallout = false
                v.image = userDotImage()
                v.centerOffset = .zero
                return v
            }
            if let pin = annotation as? RoutePin {
                let id = "RoutePin"
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: pin, reuseIdentifier: id)
                v.annotation = annotation
                v.canShowCallout = false
                // 简单白色圆点标注
                v.image = routePinImage(label: pin.routeAnnotation.label)
                v.centerOffset = CGPoint(x: 0, y: -12)
                return v
            }
            return nil
        }

        private func userDotImage() -> UIImage {
            let size: CGFloat = 20
            return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
                let c = ctx.cgContext
                c.setFillColor(UIColor.systemBlue.withAlphaComponent(0.2).cgColor)
                c.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                c.setFillColor(UIColor.white.cgColor)
                c.fillEllipse(in: CGRect(x: 3, y: 3, width: size-6, height: size-6))
                c.setFillColor(UIColor.systemBlue.cgColor)
                c.fillEllipse(in: CGRect(x: 5, y: 5, width: size-10, height: size-10))
            }
        }

        private func routePinImage(label: String) -> UIImage {
            let font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let textSize = (label as NSString).size(withAttributes: attrs)
            let padding: CGFloat = 8
            let w = max(textSize.width + padding * 2, 32)
            let h: CGFloat = 22
            return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
                let c = ctx.cgContext
                let rect = CGRect(x: 0, y: 0, width: w, height: h)
                c.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
                c.addPath(path.cgPath)
                c.fillPath()
                (label as NSString).draw(
                    at: CGPoint(x: padding, y: (h - textSize.height) / 2),
                    withAttributes: attrs
                )
            }
        }
    }
}

// MARK: - 辅助 Annotation 类型
private class UserDotAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

private class RoutePin: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var routeAnnotation: RouteAnnotation
    init(routeAnnotation: RouteAnnotation) {
        self.routeAnnotation = routeAnnotation
        self.coordinate = routeAnnotation.coordinate
    }
}
