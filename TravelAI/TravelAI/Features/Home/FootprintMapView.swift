import SwiftUI
import MapKit
import Photos
import CoreLocation

// MARK: - PhotoPointOverlay
// 轻量 MKOverlay，只持有坐标数组（不创建任何 UIView / NSObject）
final class PhotoPointOverlay: NSObject, MKOverlay {
    struct Point {
        let x: Double   // MKMapPoint.x
        let y: Double   // MKMapPoint.y
        let assetID: String
        let date: Date?
    }

    let points: [Point]
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    init(locations: [PhotoLocation]) {
        var minX = Double.infinity, minY = Double.infinity
        var maxX = -Double.infinity, maxY = -Double.infinity
        var pts = [Point]()
        pts.reserveCapacity(locations.count)

        for loc in locations {
            let mp = MKMapPoint(loc.coordinate)
            if mp.x < minX { minX = mp.x }
            if mp.y < minY { minY = mp.y }
            if mp.x > maxX { maxX = mp.x }
            if mp.y > maxY { maxY = mp.y }
            pts.append(Point(x: mp.x, y: mp.y, assetID: loc.assetIdentifier, date: loc.date))
        }

        self.points = pts
        let center = CLLocationCoordinate2D(
            latitude:  (locations.first?.coordinate.latitude  ?? 0),
            longitude: (locations.first?.coordinate.longitude ?? 0)
        )
        self.coordinate = center
        self.boundingMapRect = locations.isEmpty
            ? .world
            : MKMapRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        super.init()
    }
}

// MARK: - PhotoPointRenderer
// 在 CGContext 里直接画点，MapKit 按瓦片并发调用，只渲染可见区域
final class PhotoPointRenderer: MKOverlayRenderer {
    private let photoOverlay: PhotoPointOverlay

    // 空间索引（internal，供 handleTap 复用）
    let bucketDeg: Double = 0.5
    private(set) var buckets: [Int64: [PhotoPointOverlay.Point]] = [:]

    init(overlay: PhotoPointOverlay) {
        self.photoOverlay = overlay
        super.init(overlay: overlay)
        buildIndex(overlay.points)
    }

    private func buildIndex(_ points: [PhotoPointOverlay.Point]) {
        for pt in points {
            let coord = MKMapPoint(x: pt.x, y: pt.y).coordinate
            let bLat = Int64(floor(coord.latitude  / bucketDeg))
            let bLng = Int64(floor(coord.longitude / bucketDeg))
            let key  = bLat &* 10000 &+ bLng
            buckets[key, default: []].append(pt)
        }
    }

    // MapKit 在后台线程为每个可见瓦片调用此方法
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // 1. 查出当前瓦片内的点
        let region = MKCoordinateRegion(mapRect)
        let minLat = region.center.latitude  - region.span.latitudeDelta  / 2 - bucketDeg
        let maxLat = region.center.latitude  + region.span.latitudeDelta  / 2 + bucketDeg
        let minLng = region.center.longitude - region.span.longitudeDelta / 2 - bucketDeg
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2 + bucketDeg

        let bLatMin = Int64(floor(minLat / bucketDeg))
        let bLatMax = Int64(floor(maxLat / bucketDeg))
        let bLngMin = Int64(floor(minLng / bucketDeg))
        let bLngMax = Int64(floor(maxLng / bucketDeg))

        // 2. 根据缩放级别决定点大小和是否抽稀
        // zoomScale: 0 = 地球视角，1 = 最近
        let dotRadius: CGFloat
        let stride: Int
        switch zoomScale {
        case _ where zoomScale > 0.05:   dotRadius = 2.5 / zoomScale; stride = 1
        case _ where zoomScale > 0.01:   dotRadius = 2.0 / zoomScale; stride = 1
        case _ where zoomScale > 0.002:  dotRadius = 1.5 / zoomScale; stride = 2
        case _ where zoomScale > 0.0005: dotRadius = 1.2 / zoomScale; stride = 5
        default:                          dotRadius = 1.0 / zoomScale; stride = 10
        }
        let r = min(dotRadius, 6 / zoomScale)   // 限制最大像素半径避免遮挡

        // 3. 设置画笔
        context.setFillColor(UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.85).cgColor)

        // 4. 收集可见点并批量绘制
        var idx = 0
        for bLat in bLatMin...bLatMax {
            for bLng in bLngMin...bLngMax {
                let key = bLat &* 10000 &+ bLng
                guard let bucket = buckets[key] else { continue }
                for pt in bucket {
                    // 精确边界过滤
                    let mp = MKMapPoint(x: pt.x, y: pt.y)
                    guard mapRect.contains(mp) else { continue }
                    idx += 1
                    if idx % stride != 0 { continue }
                    let cgp = self.point(for: mp)
                    context.fillEllipse(in: CGRect(x: cgp.x - r, y: cgp.y - r,
                                                   width: r * 2, height: r * 2))
                }
            }
        }
    }
}

// MARK: - FootprintMapView
struct FootprintMapView: UIViewRepresentable {

    var photoService: PhotoMemoryService
    var photoLocationCount: Int            // 值变化时触发 updateUIView
    var segments: [[CLLocationCoordinate2D]]
    var visitedRegions: [ProvinceRegion]
    var onPhotoTap: ((String, Date?) -> Void)?
    var userCoordinate: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
        map.showsUserLocation = false
        map.showsCompass = false
        map.isRotateEnabled = true
        map.isPitchEnabled = true

        // 点击手势：用于查找最近照片点
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        let center = userCoordinate ?? CLLocationCoordinate2D(latitude: 35, longitude: 105)
        map.setRegion(MKCoordinateRegion(center: center,
                                         span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)),
                      animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.update(map: map, view: self)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: FootprintMapView
        private var lastPhotoCount  = -1
        private var lastSegmentCount = -1
        private var lastRegionCount  = -1

        init(_ parent: FootprintMapView) { self.parent = parent }

        func update(map: MKMapView, view: FootprintMapView) {
            parent = view
            let newCount = view.photoLocationCount

            // 1. 照片点 overlay（数量变化时重建）
            if newCount != lastPhotoCount {
                let old = map.overlays.filter { $0 is PhotoPointOverlay }
                if !old.isEmpty { map.removeOverlays(old) }

                if newCount > 0 {
                    // 在后台线程建索引，避免主线程卡顿
                    let locs = view.photoService.locations
                    DispatchQueue.global(qos: .userInitiated).async {
                        let overlay = PhotoPointOverlay(locations: locs)
                        DispatchQueue.main.async {
                            map.addOverlay(overlay, level: .aboveRoads)
                        }
                    }
                }
                lastPhotoCount = newCount
            }

            // 2. GPX 折线（手动导入）
            if view.segments.count != lastSegmentCount {
                let old = map.overlays.filter { $0 is MKPolyline }
                map.removeOverlays(old)
                for seg in view.segments {
                    let pts = decimate(seg, maxPoints: 3000)
                    if pts.count > 1 {
                        map.addOverlay(MKPolyline(coordinates: pts, count: pts.count),
                                       level: .aboveRoads)
                    }
                }
                lastSegmentCount = view.segments.count
            }

            // 3. 省份高亮
            if view.visitedRegions.count != lastRegionCount {
                let old = map.overlays.filter { $0 is MKPolygon }
                map.removeOverlays(old)
                for region in view.visitedRegions {
                    for poly in region.polygons {
                        map.addOverlay(MKPolygon(coordinates: poly, count: poly.count),
                                       level: .aboveRoads)
                    }
                }
                lastRegionCount = view.visitedRegions.count
            }
        }

        // MARK: - rendererFor
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let photoOverlay = overlay as? PhotoPointOverlay {
                return PhotoPointRenderer(overlay: photoOverlay)
            }
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor.white.withAlphaComponent(0.7)
                r.lineWidth = 1.5
                r.lineCap = .round
                return r
            }
            if let polygon = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: polygon)
                r.fillColor   = UIColor(red: 0, green: 0.83, blue: 0.67, alpha: 0.22)
                r.strokeColor = UIColor(red: 0, green: 0.83, blue: 0.67, alpha: 0.65)
                r.lineWidth   = 1.0
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - 点击查找最近照片点（用空间索引，O(k) 不是 O(n)）
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let screenPt  = gesture.location(in: mapView)
            let tappedCoord = mapView.convert(screenPt, toCoordinateFrom: mapView)
            let tappedMapPt = MKMapPoint(tappedCoord)

            // 点击容差：屏幕 20pt 对应的地图距离
            let tolerancePt  = mapView.convert(CGPoint(x: screenPt.x + 20, y: screenPt.y),
                                               toCoordinateFrom: mapView)
            let toleranceDist = MKMapPoint(tolerancePt).distance(to: tappedMapPt)

            guard let renderer = mapView.overlays
                    .compactMap({ mapView.renderer(for: $0) as? PhotoPointRenderer })
                    .first
            else { return }

            // 只搜索点击位置附近的 bucket（±1 格），不全量遍历
            var closest: PhotoPointOverlay.Point? = nil
            var closestDist = toleranceDist
            let bucketDeg: Double = 0.5
            let bLatCenter = Int64(floor(tappedCoord.latitude  / bucketDeg))
            let bLngCenter = Int64(floor(tappedCoord.longitude / bucketDeg))

            for dLat in -1...1 {
                for dLng in -1...1 {
                    let key = (bLatCenter + Int64(dLat)) &* 10000 &+ (bLngCenter + Int64(dLng))
                    guard let candidates = renderer.buckets[key] else { continue }
                    for pt in candidates {
                        let mp = MKMapPoint(x: pt.x, y: pt.y)
                        let d  = mp.distance(to: tappedMapPt)
                        if d < closestDist { closestDist = d; closest = pt }
                    }
                }
            }

            if let hit = closest { parent.onPhotoTap?(hit.assetID, hit.date) }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        private func decimate(_ pts: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
            guard pts.count > maxPoints else { return pts }
            let s = pts.count / maxPoints
            return pts.enumerated().compactMap {
                ($0.offset == 0 || $0.offset == pts.count - 1 || $0.offset % s == 0) ? $0.element : nil
            }
        }
    }
}

// MARK: - 照片预览弹窗
struct PhotoPreviewCard: View {
    let assetIdentifier: String
    let date: Date?
    var onDismiss: () -> Void

    @State private var image: UIImage? = nil
    @State private var appeared = false

    private var dateText: String {
        guard let d = date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月d日"
        fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: d)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 220, height: 220)
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ProgressView().tint(.white)
                }
            }
            HStack {
                if !dateText.isEmpty {
                    Text(dateText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        .scaleEffect(appeared ? 1.0 : 0.7)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { appeared = true }
            loadImage()
        }
    }

    private func loadImage() {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier], options: nil).firstObject
        else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 440, height: 440),
            contentMode: .aspectFill, options: opts
        ) { img, _ in DispatchQueue.main.async { self.image = img } }
    }
}
