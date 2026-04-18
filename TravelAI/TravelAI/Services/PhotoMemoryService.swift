import Photos
import CoreLocation
import SwiftUI

// MARK: - 照片定位点
struct PhotoLocation: Identifiable {
    let id = UUID()
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

    // 聚合后的热力格子（用于快速渲染，避免数万点卡顿）
    var clusters: [PhotoCluster] = []

    // MARK: - 请求权限并加载
    func requestAndLoad() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run { authStatus = status }
        guard status == .authorized || status == .limited else { return }
        await loadLocations()
    }

    // MARK: - 加载所有有GPS的照片
    @MainActor
    func loadLocations() async {
        isLoading = true
        defer { isLoading = false }

        let fetched: [PhotoLocation] = await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let assets = PHAsset.fetchAssets(with: .image, options: options)

            var result: [PhotoLocation] = []
            result.reserveCapacity(min(assets.count, 50_000))

            assets.enumerateObjects { asset, _, _ in
                guard let loc = asset.location,
                      abs(loc.coordinate.latitude) > 0.001 || abs(loc.coordinate.longitude) > 0.001
                else { return }
                result.append(PhotoLocation(
                    coordinate: loc.coordinate,
                    date: asset.creationDate,
                    assetIdentifier: asset.localIdentifier
                ))
            }
            return result
        }.value

        locations = fetched
        clusters = Self.cluster(fetched, gridDegrees: 0.15)  // 0.15° ≈ 16km，更密集
    }

    // MARK: - 格子聚合
    static func cluster(_ locs: [PhotoLocation], gridDegrees: Double) -> [PhotoCluster] {
        var grid: [String: (lat: Double, lng: Double, count: Int)] = [:]
        for loc in locs {
            let gLat = (loc.coordinate.latitude  / gridDegrees).rounded() * gridDegrees
            let gLng = (loc.coordinate.longitude / gridDegrees).rounded() * gridDegrees
            let key = "\(gLat),\(gLng)"
            if var existing = grid[key] {
                existing.count += 1
                grid[key] = existing
            } else {
                grid[key] = (gLat, gLng, 1)
            }
        }
        return grid.values.map { v in
            PhotoCluster(
                coordinate: CLLocationCoordinate2D(latitude: v.lat, longitude: v.lng),
                count: v.count
            )
        }
    }
}

// MARK: - 聚合光点
struct PhotoCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let count: Int

    /// 光点大小
    var dotSize: CGFloat {
        switch count {
        case 1:     return 2
        case 2...4: return 3
        case 5...14: return 4.5
        default:    return 6
        }
    }

    /// 颜色：稀疏=冷白星光，密集=暖橙亮斑
    var color: Color {
        switch count {
        case 1...2:   return Color.white.opacity(0.75)
        case 3...6:   return Color(hex: "#ffe8c0").opacity(0.85)
        case 7...19:  return Color(hex: "#ffb347").opacity(0.9)
        default:      return Color(hex: "#ff8c00")
        }
    }

    var glowRadius: CGFloat {
        count >= 10 ? dotSize * 1.5 : 0
    }
}
