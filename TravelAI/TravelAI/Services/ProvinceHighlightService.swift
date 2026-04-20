import Foundation
import CoreLocation
import SwiftUI
import MapKit
import SwiftData

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
    func loadAndCompute(trips: [Trip], photoLocations: [PhotoLocation]) async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }

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

        // 3. 点在多边形内判断（后台线程）
        // 预构建所有 renderer（createPath 后可重复使用）
        let (visitedIDs, countryCodes) = await Task.detached(priority: .userInitiated) {
            var ids = Set<String>()
            var countries = Set<String>()

            struct RendererEntry {
                let regionID: String
                let country: String
                let renderer: MKPolygonRenderer
            }
            var entries: [RendererEntry] = []
            for region in regions {
                for poly in region.polygons {
                    guard poly.count > 2 else { continue }
                    let mkPoly = MKPolygon(coordinates: poly, count: poly.count)
                    let renderer = MKPolygonRenderer(polygon: mkPoly)
                    renderer.createPath()   // 预先生成 CGPath
                    entries.append(RendererEntry(regionID: region.id, country: region.country, renderer: renderer))
                }
            }

            for coord in coords {
                let mapPoint = MKMapPoint(coord)
                for entry in entries {
                    guard !ids.contains(entry.regionID) else { continue }
                    if entry.renderer.path?.contains(entry.renderer.point(for: mapPoint)) == true {
                        ids.insert(entry.regionID)
                        countries.insert(entry.country)
                    }
                }
            }
            return (ids, countries)
        }.value

        await MainActor.run {
            self.allRegions = regions
            self.visitedProvinceIDs = visitedIDs
            self.visitedCountryCodes = countryCodes
            self.isLoading = false
        }
    }

    // MARK: - 统计
    var visitedProvinceCount: Int { visitedProvinceIDs.count }
    var visitedCountryCount: Int { visitedCountryCodes.count }

    // 已访问的 ProvinceRegion 列表（用于渲染）
    var visitedRegions: [ProvinceRegion] {
        allRegions.filter { visitedProvinceIDs.contains($0.id) }
    }
}
