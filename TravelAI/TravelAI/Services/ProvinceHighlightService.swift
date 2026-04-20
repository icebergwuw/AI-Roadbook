import Foundation
import CoreLocation

// MARK: - ProvinceHighlightService
@Observable
final class ProvinceHighlightService {

    // 已到访省份 id 集合（adcode / GID_1）
    var visitedProvinceIDs: Set<String> = []
    // 已到访国家代码集合（"CN" / "JP" …）
    var visitedCountryCodes: Set<String> = []

    var isLoading = false

    // 所有省份区域（加载一次后缓存）
    private(set) var allRegions: [ProvinceRegion] = []

    // MARK: - 加载 GeoJSON 并计算已访问省份
    @MainActor
    func loadAndCompute(trips: [Trip], photoLocations: [PhotoLocation]) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // 1. 加载 GeoJSON（后台线程）
        let regions: [ProvinceRegion] = await Task.detached(priority: .userInitiated) {
            var all: [ProvinceRegion] = []
            all += FootprintGeoJSONLoader.load(filename: "provinces-cn.geojson", country: "CN")
            // 世界数据（Task 7 加入后取消注释）
            // all += FootprintGeoJSONLoader.load(filename: "provinces-world.geojson", country: "WORLD")
            return all
        }.value

        // 2. 收集所有坐标点（行程 + 照片）
        var coords: [CLLocationCoordinate2D] = []
        for trip in trips {
            for day in trip.days {
                for event in day.events {
                    if let lat = event.latitude, let lng = event.longitude,
                       lat != 0, lng != 0 {
                        coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                    }
                }
            }
        }
        for photo in photoLocations {
            coords.append(photo.coordinate)
        }

        // 3. 点在多边形内判断（纯数学射线法，后台线程安全）
        let (visitedIDs, countryCodes) = await Task.detached(priority: .userInitiated) {
            var ids = Set<String>()
            var countries = Set<String>()

            for region in regions {
                guard !ids.contains(region.id) else { continue }
                outer: for coord in coords {
                    for poly in region.polygons {
                        if Self.polygonContains(poly, point: coord) {
                            ids.insert(region.id)
                            countries.insert(region.country)
                            break outer
                        }
                    }
                }
            }
            return (ids, countries)
        }.value

        // 4. 写回主线程（已在 MainActor 上，直接赋值）
        allRegions = regions
        visitedProvinceIDs = visitedIDs
        visitedCountryCodes = countryCodes
    }

    // MARK: - 统计
    var visitedProvinceCount: Int { visitedProvinceIDs.count }
    var visitedCountryCount: Int { visitedCountryCodes.count }

    // 已访问的 ProvinceRegion 列表（用于渲染）
    var visitedRegions: [ProvinceRegion] {
        allRegions.filter { visitedProvinceIDs.contains($0.id) }
    }

    // MARK: - 射线法点在多边形内判断
    private nonisolated static func polygonContains(_ polygon: [CLLocationCoordinate2D],
                                         point: CLLocationCoordinate2D) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude, yi = polygon[i].latitude
            let xj = polygon[j].longitude, yj = polygon[j].latitude
            if ((yi > point.latitude) != (yj > point.latitude)) &&
               (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
