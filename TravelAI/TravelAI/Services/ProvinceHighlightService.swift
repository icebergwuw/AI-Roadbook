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

    // 所有省份区域（首次加载后永久缓存，不重复读文件）
    private(set) var allRegions: [ProvinceRegion] = []
    // 已访问区域列表（stored property，避免每帧 filter）
    private(set) var visitedRegions: [ProvinceRegion] = []

    // MARK: - 加载 GeoJSON 并计算已访问省份
    @MainActor
    func loadAndCompute(trips: [Trip], photoLocations: [PhotoLocation]) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // 1. 加载 GeoJSON（只在首次调用时读文件，后续复用缓存）
        let regions: [ProvinceRegion]
        if !allRegions.isEmpty {
            regions = allRegions
        } else {
            regions = await Task.detached(priority: .userInitiated) {
                var all: [ProvinceRegion] = []
                all += FootprintGeoJSONLoader.load(filename: "provinces-cn.geojson", country: "CN")
                all += FootprintGeoJSONLoader.load(filename: "provinces-world.geojson", country: "WORLD")
                return all
            }.value
        }

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

        // 3. 点在多边形内判断（后台线程）
        let (visitedIDs, countryCodes, visited) = await Task.detached(priority: .userInitiated) {
            var ids = Set<String>()
            var countries = Set<String>()
            var visitedList: [ProvinceRegion] = []

            for region in regions {
                guard !ids.contains(region.id) else { continue }
                outer: for coord in coords {
                    for poly in region.polygons {
                        if Self.polygonContains(poly, point: coord) {
                            ids.insert(region.id)
                            countries.insert(region.country)
                            visitedList.append(region)
                            break outer
                        }
                    }
                }
            }
            return (ids, countries, visitedList)
        }.value

        // 4. 写回主线程
        allRegions = regions
        visitedProvinceIDs = visitedIDs
        visitedCountryCodes = countryCodes
        visitedRegions = visited
    }

    // MARK: - 统计
    var visitedProvinceCount: Int { visitedProvinceIDs.count }
    var visitedCountryCount: Int { visitedCountryCodes.count }

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
