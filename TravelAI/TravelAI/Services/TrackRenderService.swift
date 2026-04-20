import Foundation
import CoreLocation
import SwiftData
import MapKit

struct HeatCell {
    let coordinate: CLLocationCoordinate2D
    let density: Double  // 0.0 ~ 1.0
}

@Observable
@MainActor
final class TrackRenderService {
    private(set) var allPoints: [CLLocationCoordinate2D] = []
    /// 所有可见轨迹段（含照片轨迹）
    private(set) var segments: [[CLLocationCoordinate2D]] = []
    /// 仅手动导入的GPX轨迹段（不含照片轨迹），供足迹地图叠加折线用
    private(set) var manualSegments: [[CLLocationCoordinate2D]] = []
    private var spatialGrid: [Int64: [CLLocationCoordinate2D]] = [:]
    private let spatialGridDeg: Double = 0.5
    var isLoading = false
    var daySpanCount: Int = 0
    var totalPointCount: Int { allPoints.count }

    func load(imports: [TrackImport]) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let gridDeg = spatialGridDeg
        let result = await Task.detached(priority: .userInitiated) { [imports, gridDeg] in
            var coords: [CLLocationCoordinate2D] = []
            var grid: [Int64: [CLLocationCoordinate2D]] = [:]
            var segs: [[CLLocationCoordinate2D]] = []
            var manualSegs: [[CLLocationCoordinate2D]] = []
            var days = Set<String>()
            let cal = Calendar.current
            coords.reserveCapacity(imports.reduce(0) { $0 + $1.totalPoints })
            for imp in imports where imp.isVisible {
                let sorted = imp.points.sorted { $0.sortIndex < $1.sortIndex }
                var seg: [CLLocationCoordinate2D] = []
                seg.reserveCapacity(sorted.count)
                for pt in sorted {
                    let c = CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude)
                    coords.append(c)
                    seg.append(c)
                    let bLat = Int64(pt.latitude  / gridDeg)
                    let bLng = Int64(pt.longitude / gridDeg)
                    let key  = bLat &* 10000 &+ bLng
                    grid[key, default: []].append(c)
                    if let ts = pt.timestamp {
                        let comps = cal.dateComponents([.year, .month, .day], from: ts)
                        days.insert("\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)")
                    }
                }
                if !seg.isEmpty {
                    segs.append(seg)
                    if !imp.isPhotoTrack { manualSegs.append(seg) }
                }
            }
            return (coords, grid, days.count, segs, manualSegs)
        }.value

        allPoints      = result.0
        spatialGrid    = result.1
        daySpanCount   = result.2
        segments       = result.3
        manualSegments = result.4
    }

    func points(in mapRect: MKMapRect, zoomScale: MKZoomScale) -> [CLLocationCoordinate2D] {
        let region = MKCoordinateRegion(mapRect)
        let minLat = region.center.latitude  - region.span.latitudeDelta  / 2
        let maxLat = region.center.latitude  + region.span.latitudeDelta  / 2
        let minLng = region.center.longitude - region.span.longitudeDelta / 2
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2
        let minBLat = Int64(minLat / spatialGridDeg) - 1
        let maxBLat = Int64(maxLat / spatialGridDeg) + 1
        let minBLng = Int64(minLng / spatialGridDeg) - 1
        let maxBLng = Int64(maxLng / spatialGridDeg) + 1
        var visible: [CLLocationCoordinate2D] = []
        for bLat in minBLat...maxBLat {
            for bLng in minBLng...maxBLng {
                let key = bLat &* 10000 &+ bLng
                guard let bucket = spatialGrid[key] else { continue }
                for c in bucket {
                    if c.latitude >= minLat && c.latitude <= maxLat &&
                       c.longitude >= minLng && c.longitude <= maxLng {
                        visible.append(c)
                    }
                }
            }
        }
        let stride = lodStride(for: zoomScale, totalVisible: visible.count)
        if stride <= 1 { return visible }
        return visible.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
    }

    func heatCells(in mapRect: MKMapRect, zoomScale: MKZoomScale, gridDeg: Double = 0.05) -> [HeatCell] {
        let pts = points(in: mapRect, zoomScale: zoomScale)
        guard !pts.isEmpty else { return [] }
        var grid: [String: Int] = [:]
        for c in pts {
            let gLat = (c.latitude  / gridDeg).rounded() * gridDeg
            let gLng = (c.longitude / gridDeg).rounded() * gridDeg
            grid["\(gLat)|\(gLng)", default: 0] += 1
        }
        let maxCount = Double(grid.values.max() ?? 1)
        return grid.map { key, count in
            let parts = key.split(separator: "|")
            let lat = Double(parts[0]) ?? 0
            let lng = Double(parts[1]) ?? 0
            return HeatCell(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                            density: Double(count) / maxCount)
        }
    }

    nonisolated func lodStride(for zoomScale: MKZoomScale, totalVisible: Int) -> Int {
        let maxRenderPoints = 8_000
        guard totalVisible > maxRenderPoints else { return 1 }
        let zoomFactor: Int
        switch zoomScale {
        case _ where zoomScale > 0.05:   zoomFactor = 1
        case _ where zoomScale > 0.01:   zoomFactor = 2
        case _ where zoomScale > 0.002:  zoomFactor = 5
        case _ where zoomScale > 0.0005: zoomFactor = 15
        default:                          zoomFactor = 50
        }
        return max(1, (totalVisible / maxRenderPoints) * zoomFactor)
    }
}
