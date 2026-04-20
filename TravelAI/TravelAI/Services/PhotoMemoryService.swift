import Photos
import CoreLocation
import SwiftUI

// MARK: - 照片定位点
struct PhotoLocation: Identifiable {
    let id: String   // 用 assetIdentifier 作 stable ID
    let coordinate: CLLocationCoordinate2D
    let date: Date?
    let assetIdentifier: String
}

// MARK: - PhotoMemoryService
@Observable
final class PhotoMemoryService {

    var locations: [PhotoLocation] = []
    var authStatus: PHAuthorizationStatus = .notDetermined
    var isLoading = false

    // MARK: - 请求权限并加载
    func requestAndLoad() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run { authStatus = status }
        guard status == .authorized || status == .limited else { return }
        await loadLocations()
    }

    // MARK: - 加载所有有GPS的照片（完全后台，不阻塞主线程）
    @MainActor
    func loadLocations() async {
        isLoading = true
        defer { isLoading = false }

        let fetched: [PhotoLocation] = await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.includeAssetSourceTypes = [.typeUserLibrary]   // 去掉 cloudShared 减少 I/O
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let assets = PHAsset.fetchAssets(with: .image, options: options)

            var result: [PhotoLocation] = []
            result.reserveCapacity(min(assets.count, 60_000))

            assets.enumerateObjects { asset, _, _ in
                guard let loc = asset.location,
                      abs(loc.coordinate.latitude)  > 0.001 ||
                      abs(loc.coordinate.longitude) > 0.001
                else { return }
                result.append(PhotoLocation(
                    id: asset.localIdentifier,
                    coordinate: loc.coordinate,
                    date: asset.creationDate,
                    assetIdentifier: asset.localIdentifier
                ))
            }
            return result
        }.value

        locations = fetched
    }

    // MARK: - 导出为 GPX Data（按日期分 trkseg，每天一段）
    func exportGPXData() -> Data? {
        guard !locations.isEmpty else { return nil }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]

        let cal = Calendar.current
        let byDay = Dictionary(grouping: locations) { loc -> String in
            guard let d = loc.date else { return "unknown" }
            let c = cal.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        let sortedDays = byDay.keys.sorted()

        // 用数组拼接避免大字符串多次复制
        var parts: [String] = []
        parts.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TravelAI-PhotoMemory"
             xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>Photo Memories</name>
        """)

        for day in sortedDays {
            guard let pts = byDay[day] else { continue }
            let sorted = pts.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            parts.append("\n    <trkseg>")
            for loc in sorted {
                let lat = String(format: "%.7f", loc.coordinate.latitude)
                let lon = String(format: "%.7f", loc.coordinate.longitude)
                var trkpt = "\n      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">"
                if let d = loc.date {
                    trkpt += "<time>\(fmt.string(from: d))</time>"
                }
                trkpt += "</trkpt>"
                parts.append(trkpt)
            }
            parts.append("\n    </trkseg>")
        }
        parts.append("\n  </trk>\n</gpx>\n")
        return parts.joined().data(using: .utf8)
    }
}
