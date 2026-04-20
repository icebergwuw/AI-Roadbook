import Foundation
import CoreLocation
import MapKit

// MARK: - 省份多边形模型
struct ProvinceRegion: Identifiable {
    let id: String               // adcode 或 ISO 代码
    let name: String             // 显示名称（"广东省" / "California" 等）
    let country: String          // "CN" / "US" / "JP" …
    let polygons: [[CLLocationCoordinate2D]]  // 支持 MultiPolygon，每个子数组是一个环
    let center: CLLocationCoordinate2D?
}

// MARK: - GeoJSON 解析器（纯静态工具）
enum FootprintGeoJSONLoader: Sendable {

    /// 从 bundle 加载指定文件名的 GeoJSON，解析为 [ProvinceRegion]
    nonisolated static func load(filename: String, country: String) -> [ProvinceRegion] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]]
        else {
            print("[FootprintGeoJSON] ⚠️ 无法加载 \(filename)")
            return []
        }

        var result: [ProvinceRegion] = []
        for feature in features {
            guard let props = feature["properties"] as? [String: Any],
                  let geometry = feature["geometry"] as? [String: Any],
                  let geoType = geometry["type"] as? String
            else { continue }

            let name = props["name"] as? String
                    ?? props["NAME_1"] as? String
                    ?? props["shapeName"] as? String
                    ?? "Unknown"

            // adcode 可能是 Int 或 String（阿里云DataV返回的是Int）
            let adcode: String
            if let adcodeInt = props["adcode"] as? Int {
                adcode = String(adcodeInt)
            } else if let adcodeStr = props["adcode"] as? String {
                adcode = adcodeStr
            } else if let gid = props["GID_1"] as? String {
                adcode = gid
            } else if let iso = props["shapeISO"] as? String {
                adcode = iso
            } else if let adm1 = props["adm1_code"] as? String {
                // Natural Earth / provinces-world.geojson uses adm1_code (e.g. "USA-3521", "JPN-1860")
                adcode = adm1
            } else {
                adcode = UUID().uuidString
            }

            // 解析中心点（可选）
            let center: CLLocationCoordinate2D?
            if let centerArr = props["center"] as? [Double], centerArr.count >= 2 {
                center = CLLocationCoordinate2D(latitude: centerArr[1], longitude: centerArr[0])
            } else {
                center = nil
            }

            // 尝试从 properties 读取真实 ISO 国家代码
            let resolvedCountry = (props["iso_a2"] as? String
                                ?? props["ISO_A2"] as? String
                                ?? country).uppercased()

            // 解析多边形坐标
            let polys: [[CLLocationCoordinate2D]]
            switch geoType {
            case "Polygon":
                if let rings = geometry["coordinates"] as? [[[Double]]],
                   let outer = rings.first {
                    polys = [outer.compactMap { coordinateFromArray($0) }]
                } else { continue }

            case "MultiPolygon":
                if let multiRings = geometry["coordinates"] as? [[[[Double]]]] {
                    polys = multiRings.compactMap { rings in
                        rings.first.map { $0.compactMap { coordinateFromArray($0) } }
                    }
                } else { continue }

            default: continue
            }

            guard !polys.isEmpty else { continue }
            result.append(ProvinceRegion(
                id: adcode,
                name: name,
                country: resolvedCountry,
                polygons: polys,
                center: center
            ))
        }
        return result
    }

    nonisolated private static func coordinateFromArray(_ arr: [Double]) -> CLLocationCoordinate2D? {
        guard arr.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: arr[1], longitude: arr[0])
    }
}
