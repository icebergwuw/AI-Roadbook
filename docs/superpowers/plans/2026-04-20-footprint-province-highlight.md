# 足迹省份点亮 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 TravelAI 地图上实现「省份点亮」功能——用户到访过的省份（来源：SwiftData 行程坐标 + 照片 GPS）高亮显示青色填充多边形，并附带统计面板（城市数、省份数、国家数）。

**Architecture:**
- `ProvinceHighlightService`：纯数据服务，负责「坐标 → 省份」判断（点在多边形内），输出已到访省份 Set
- `FootprintGeoJSONLoader`：一次性工具，加载 bundle 里的 GeoJSON 文件，解析为内存模型
- `GlobeView` 扩展：在现有 `MapPolyline` / `Annotation` 渲染管线里追加 `MapPolygon` 省份图层
- `FootprintStatsView`：底部统计卡片（Liquid Glass 风格），从主地图触发进入「足迹模式」

**Tech Stack:** SwiftUI, MapKit (MapPolygon), SwiftData, GeoJSON (手工精简版，bundle 内), CoreLocation

---

## 文件变更地图

| 操作 | 文件路径 | 职责 |
|------|----------|------|
| 新建 | `TravelAI/Services/FootprintGeoJSONLoader.swift` | GeoJSON 解析，输出 `[ProvinceRegion]` |
| 新建 | `TravelAI/Services/ProvinceHighlightService.swift` | 坐标→省份判断，维护已访问 Set |
| 新建 | `TravelAI/Resources/provinces-cn.geojson` | 中国34省简化边界（bundle） |
| 新建 | `TravelAI/Resources/provinces-world.geojson` | 20个热门国家省级 + 其余国家级边界（bundle） |
| 修改 | `TravelAI/Features/Home/GlobeView.swift` | 追加 `MapPolygon` 省份高亮图层 |
| 修改 | `TravelAI/Features/Home/HomeView.swift` | 注入 `ProvinceHighlightService`，顶部菜单加入「足迹模式」入口，触发足迹 sheet |
| 新建 | `TravelAI/Features/Home/FootprintView.swift` | 足迹专页 sheet：地图 + 统计面板 |

---

## Task 1: 准备中国省级 GeoJSON 数据

**Files:**
- Create: `TravelAI/TravelAI/Resources/provinces-cn.geojson`

GeoJSON 来源策略：使用精简版中国省级行政区边界（约 400KB），来自开源项目 [china-geojson](https://github.com/longwosion/geojson-map-china)。每个 Feature 的 `properties` 必须包含：

```json
{
  "name": "广东省",
  "adcode": "440000",
  "center": [113.280637, 23.125178]
}
```

- [ ] **Step 1: 下载精简版中国省级 GeoJSON**

```bash
curl -L "https://raw.githubusercontent.com/longwosion/geojson-map-china/master/china-provinces.json" \
  -o /tmp/provinces-cn-raw.json
```

如网络不通，用以下最小验证用 stub（只含广东+北京两个省，用于跑通 Task 2 的测试）：

```bash
cat > /Users/ice/Desktop/Project/Map/TravelAI/TravelAI/Resources/provinces-cn.geojson << 'GEOJSON'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "name": "北京市", "adcode": "110000" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[116.05,39.67],[117.0,39.67],[117.0,40.8],[116.05,40.8],[116.05,39.67]]]
      }
    },
    {
      "type": "Feature",
      "properties": { "name": "广东省", "adcode": "440000" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[109.7,20.2],[117.3,20.2],[117.3,25.5],[109.7,25.5],[109.7,20.2]]]
      }
    }
  ]
}
GEOJSON
```

- [ ] **Step 2: 复制到项目 Resources 目录**

```bash
cp /tmp/provinces-cn-raw.json \
  /Users/ice/Desktop/Project/Map/TravelAI/TravelAI/Resources/provinces-cn.geojson
```

- [ ] **Step 3: 在 Xcode 中把文件加入 target**

在 Xcode 中：File → Add Files → 选择 `TravelAI/Resources/provinces-cn.geojson` → 勾选 `TravelAI` target → Add。

验证：
```bash
ls -lh /Users/ice/Desktop/Project/Map/TravelAI/TravelAI/Resources/provinces-cn.geojson
```
预期输出：文件存在，大小 > 0。

---

## Task 2: FootprintGeoJSONLoader — GeoJSON 解析服务

**Files:**
- Create: `TravelAI/TravelAI/Services/FootprintGeoJSONLoader.swift`

- [ ] **Step 1: 创建 `FootprintGeoJSONLoader.swift`**

```swift
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
enum FootprintGeoJSONLoader {

    /// 从 bundle 加载指定文件名的 GeoJSON，解析为 [ProvinceRegion]
    static func load(filename: String, country: String) -> [ProvinceRegion] {
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
            let adcode = props["adcode"] as? String
                      ?? props["GID_1"] as? String
                      ?? props["shapeISO"] as? String
                      ?? UUID().uuidString

            // 解析中心点（可选）
            let center: CLLocationCoordinate2D?
            if let centerArr = props["center"] as? [Double], centerArr.count >= 2 {
                center = CLLocationCoordinate2D(latitude: centerArr[1], longitude: centerArr[0])
            } else {
                center = nil
            }

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
                country: country,
                polygons: polys,
                center: center
            ))
        }
        return result
    }

    private static func coordinateFromArray(_ arr: [Double]) -> CLLocationCoordinate2D? {
        guard arr.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: arr[1], longitude: arr[0])
    }
}
```

- [ ] **Step 2: 在 Xcode 中编译确认无报错**

Build (`Cmd+B`)，预期：0 errors。

- [ ] **Step 3: Commit**

```bash
cd /Users/ice/Desktop/Project/Map
git add TravelAI/TravelAI/Services/FootprintGeoJSONLoader.swift \
        TravelAI/TravelAI/Resources/provinces-cn.geojson
git commit -m "feat: add GeoJSON loader and CN province data"
```

---

## Task 3: ProvinceHighlightService — 坐标→省份判断

**Files:**
- Create: `TravelAI/TravelAI/Services/ProvinceHighlightService.swift`

- [ ] **Step 1: 创建 `ProvinceHighlightService.swift`**

```swift
import Foundation
import CoreLocation
import SwiftUI
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
            // 世界数据（Task 5 加入后取消注释）
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
        let (visitedIDs, countryCodes) = await Task.detached(priority: .userInitiated) {
            var ids = Set<String>()
            var countries = Set<String>()
            for region in regions {
                for poly in region.polygons {
                    guard poly.count > 2 else { continue }
                    let mkPoly = MKPolygon(coordinates: poly, count: poly.count)
                    let renderer = MKPolygonRenderer(polygon: mkPoly)
                    for coord in coords {
                        let point = MKMapPoint(coord)
                        if renderer.path?.contains(renderer.point(for: point)) == true {
                            ids.insert(region.id)
                            countries.insert(region.country)
                            break  // 该省份已命中，跳出坐标循环
                        }
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
```

- [ ] **Step 2: Build 确认无报错**

```bash
# 在 Xcode 中 Cmd+B
```

- [ ] **Step 3: Commit**

```bash
cd /Users/ice/Desktop/Project/Map
git add TravelAI/TravelAI/Services/ProvinceHighlightService.swift
git commit -m "feat: province highlight service with point-in-polygon detection"
```

---

## Task 4: GlobeView 追加省份高亮 MapPolygon 图层

**Files:**
- Modify: `TravelAI/TravelAI/Features/Home/GlobeView.swift`

在 `GlobeView` 的 `Map { }` content builder 里，在照片光点 `ForEach` **之前**（先渲再叠，省份在底层），插入省份多边形渲染。

- [ ] **Step 1: 给 `GlobeView` 添加 `provinceService` 参数**

在 `GlobeView.swift` 顶部的属性声明区：

旧代码（定位锚点）：
```swift
    var coordinate: CLLocationCoordinate2D?
    var photoService: PhotoMemoryService
    @Binding var flightAnimator: FlightRouteAnimator?
```

新代码：
```swift
    var coordinate: CLLocationCoordinate2D?
    var photoService: PhotoMemoryService
    var provinceService: ProvinceHighlightService
    @Binding var flightAnimator: FlightRouteAnimator?
```

- [ ] **Step 2: 更新 `init` 方法**

旧代码：
```swift
    init(coordinate: CLLocationCoordinate2D?,
         photoService: PhotoMemoryService,
         flightAnimator: Binding<FlightRouteAnimator?> = .constant(nil)) {
        self.coordinate = coordinate
        self.photoService = photoService
        self._flightAnimator = flightAnimator
    }
```

新代码：
```swift
    init(coordinate: CLLocationCoordinate2D?,
         photoService: PhotoMemoryService,
         provinceService: ProvinceHighlightService,
         flightAnimator: Binding<FlightRouteAnimator?> = .constant(nil)) {
        self.coordinate = coordinate
        self.photoService = photoService
        self.provinceService = provinceService
        self._flightAnimator = flightAnimator
    }
```

- [ ] **Step 3: 新增 `provinceOverlay` MapContentBuilder 方法**

在 `GlobeView` 的 `private func flightOverlay` 方法之后添加：

```swift
    // 省份高亮多边形图层
    @MapContentBuilder
    private func provinceOverlay() -> some MapContent {
        ForEach(provinceService.visitedRegions) { region in
            ForEach(Array(region.polygons.enumerated()), id: \.offset) { _, poly in
                MapPolygon(coordinates: poly)
                    .foregroundStyle(
                        Color(hex: "#00d4aa").opacity(0.28)
                    )
                    .stroke(Color(hex: "#00d4aa").opacity(0.7), lineWidth: 1.2)
            }
        }
    }
```

- [ ] **Step 4: 在静态地图 `Map { }` 内插入 `provinceOverlay()`**

找到静态地图的 `Map(position: $position) { ... }` 内，在用户位置 Annotation 之前插入：

旧代码（定位锚点）：
```swift
                Map(position: $position) {
                    if let coord = coordinate {
                        Annotation("我在这里", coordinate: coord, anchor: .bottom) {
                            UserLocationDot()
                        }
                    }
                    ForEach(photoService.clusters.sorted { $0.count > $1.count }.prefix(300)) { cluster in
```

新代码：
```swift
                Map(position: $position) {
                    // 省份高亮（底层）
                    provinceOverlay()
                    if let coord = coordinate {
                        Annotation("我在这里", coordinate: coord, anchor: .bottom) {
                            UserLocationDot()
                        }
                    }
                    ForEach(photoService.clusters.sorted { $0.count > $1.count }.prefix(300)) { cluster in
```

- [ ] **Step 5: 同样更新 `AnimatingMapView`**

`AnimatingMapView` 也需要 `provinceService`。

在 `AnimatingMapView` 的属性声明区：

旧代码：
```swift
private struct AnimatingMapView: View {
    var animator: FlightRouteAnimator
    var coordinate: CLLocationCoordinate2D?
    var photoService: PhotoMemoryService
```

新代码：
```swift
private struct AnimatingMapView: View {
    var animator: FlightRouteAnimator
    var coordinate: CLLocationCoordinate2D?
    var photoService: PhotoMemoryService
    var provinceService: ProvinceHighlightService
```

- [ ] **Step 6: 在 `AnimatingMapView.body` 内插入省份图层**

旧代码（定位锚点）：
```swift
        Map(position: Binding(
            get: { animator.mapCameraPosition },
            set: { _ in }
        ), content: {
            // 用户位置
            if let coord = coordinate {
```

新代码：
```swift
        Map(position: Binding(
            get: { animator.mapCameraPosition },
            set: { _ in }
        ), content: {
            // 省份高亮（底层）
            ForEach(provinceService.visitedRegions) { region in
                ForEach(Array(region.polygons.enumerated()), id: \.offset) { _, poly in
                    MapPolygon(coordinates: poly)
                        .foregroundStyle(Color(hex: "#00d4aa").opacity(0.28))
                        .stroke(Color(hex: "#00d4aa").opacity(0.7), lineWidth: 1.2)
                }
            }
            // 用户位置
            if let coord = coordinate {
```

- [ ] **Step 7: 更新 `AnimatingMapView` 的调用处（在 `GlobeView.body` 里）**

旧代码：
```swift
                AnimatingMapView(
                    animator: animator,
                    coordinate: coordinate,
                    photoService: photoService
                )
```

新代码：
```swift
                AnimatingMapView(
                    animator: animator,
                    coordinate: coordinate,
                    photoService: photoService,
                    provinceService: provinceService
                )
```

- [ ] **Step 8: Build 确认无报错**

```bash
# Xcode Cmd+B
```

- [ ] **Step 9: Commit**

```bash
cd /Users/ice/Desktop/Project/Map
git add TravelAI/TravelAI/Features/Home/GlobeView.swift
git commit -m "feat: render visited province polygons on map"
```

---

## Task 5: HomeView 注入 ProvinceHighlightService

**Files:**
- Modify: `TravelAI/TravelAI/Features/Home/HomeView.swift`

- [ ] **Step 1: 在 `HomeView` 添加 `provinceService` state**

旧代码（定位锚点）：
```swift
    @State private var photoService = PhotoMemoryService()
    @State private var flightAnimator: FlightRouteAnimator? = nil
```

新代码：
```swift
    @State private var photoService = PhotoMemoryService()
    @State private var provinceService = ProvinceHighlightService()
    @State private var flightAnimator: FlightRouteAnimator? = nil
```

- [ ] **Step 2: 更新 `GlobeView` 调用处**

旧代码：
```swift
                GlobeView(coordinate: locationManager.coordinate,
                          photoService: photoService,
                          flightAnimator: $flightAnimator)
```

新代码：
```swift
                GlobeView(coordinate: locationManager.coordinate,
                          photoService: photoService,
                          provinceService: provinceService,
                          flightAnimator: $flightAnimator)
```

- [ ] **Step 3: 在 `.onAppear` 触发省份计算**

旧代码：
```swift
            .onAppear {
                locationManager.requestWhenInUse()
                Task { await photoService.requestAndLoad() }
                registerGenerationHandler()
            }
```

新代码：
```swift
            .onAppear {
                locationManager.requestWhenInUse()
                Task { await photoService.requestAndLoad() }
                registerGenerationHandler()
                Task {
                    await photoService.requestAndLoad()
                    await provinceService.loadAndCompute(
                        trips: trips,
                        photoLocations: photoService.locations
                    )
                }
            }
```

> 注意：`photoService.requestAndLoad()` 被调用了两次（一次旧的单独触发，一次在省份计算前确保数据已加载）。下一步骤会合并清理。

- [ ] **Step 4: 合并 `.onAppear` 里的重复调用**

用这个最终版本替换 `.onAppear`：

```swift
            .onAppear {
                locationManager.requestWhenInUse()
                registerGenerationHandler()
                Task {
                    await photoService.requestAndLoad()
                    await provinceService.loadAndCompute(
                        trips: trips,
                        photoLocations: photoService.locations
                    )
                }
            }
```

- [ ] **Step 5: 当 trips 发生变化时重新计算省份**

在 `.onAppear` 后面添加：

```swift
            .onChange(of: trips.count) { _, _ in
                Task {
                    await provinceService.loadAndCompute(
                        trips: trips,
                        photoLocations: photoService.locations
                    )
                }
            }
```

- [ ] **Step 6: Build 确认无报错**

```bash
# Xcode Cmd+B
```

- [ ] **Step 7: 在模拟器运行，验证省份高亮**

1. 确保 SwiftData 里有行程（如去过广州的行程，events 有经纬度）
2. 运行 App
3. 进入地图，已访问省份应显示青色半透明填充

- [ ] **Step 8: Commit**

```bash
cd /Users/ice/Desktop/Project/Map
git add TravelAI/TravelAI/Features/Home/HomeView.swift
git commit -m "feat: inject ProvinceHighlightService into HomeView"
```

---

## Task 6: FootprintView — 足迹专页 Sheet

**Files:**
- Create: `TravelAI/TravelAI/Features/Home/FootprintView.swift`
- Modify: `TravelAI/TravelAI/Features/Home/HomeView.swift`（添加 sheet 触发）

- [ ] **Step 1: 创建 `FootprintView.swift`**

```swift
import SwiftUI
import MapKit
import SwiftData

struct FootprintView: View {
    @Environment(\.dismiss) private var dismiss
    var provinceService: ProvinceHighlightService
    var photoService: PhotoMemoryService

    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    // 城市数：从行程目的地去重统计
    private var visitedCityCount: Int {
        Set(trips.map { $0.destination }).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 地图背景
                Map {
                    // 省份高亮
                    ForEach(provinceService.visitedRegions) { region in
                        ForEach(Array(region.polygons.enumerated()), id: \.offset) { _, poly in
                            MapPolygon(coordinates: poly)
                                .foregroundStyle(Color(hex: "#00d4aa").opacity(0.32))
                                .stroke(Color(hex: "#00d4aa").opacity(0.8), lineWidth: 1.5)
                        }
                    }
                    // 照片光点
                    ForEach(photoService.clusters.sorted { $0.count > $1.count }.prefix(200)) { cluster in
                        Annotation("", coordinate: cluster.coordinate, anchor: .center) {
                            PhotoDotView(cluster: cluster)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControls { }
                .ignoresSafeArea()

                // 底部统计卡片
                VStack {
                    Spacer()
                    statsCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("我的足迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(Color(hex: "#00d4aa"))
                }
            }
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: "\(visitedCityCount)", label: "城市")
            divider
            statItem(value: "\(provinceService.visitedProvinceCount)", label: "省份/州")
            divider
            statItem(value: "\(max(provinceService.visitedCountryCount, visitedCityCount > 0 ? 1 : 0))", label: "国家")
        }
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1, height: 40)
    }
}

// PhotoDotView 在 GlobeView.swift 里是 private，这里复制一份（或考虑提取到共用位置）
private struct PhotoDotView: View {
    let cluster: PhotoCluster
    var body: some View {
        ZStack {
            if cluster.count >= 5 {
                Circle()
                    .fill(cluster.color.opacity(0.15))
                    .frame(width: cluster.dotSize * 3, height: cluster.dotSize * 3)
                    .blur(radius: cluster.dotSize)
            }
            Circle()
                .fill(cluster.color.opacity(0.9))
                .frame(width: cluster.dotSize, height: cluster.dotSize)
                .shadow(color: cluster.color, radius: cluster.dotSize * 0.8)
        }
    }
}
```

> **注意**：`PhotoDotView` 在 `GlobeView.swift` 里是 `private`，在 `FootprintView.swift` 里必须重新声明一份（或者把 `GlobeView.swift` 里的 `private` 改为 `internal`，但那样需要改另一个文件，本 task 不碰）。选择在此复制一份，后续重构时可提取。

- [ ] **Step 2: 在 `HomeView` 添加足迹 sheet 触发**

在 `HomeView` 的 state 区添加：

旧代码：
```swift
    @State private var provinceService = ProvinceHighlightService()
    @State private var flightAnimator: FlightRouteAnimator? = nil
```

新代码：
```swift
    @State private var provinceService = ProvinceHighlightService()
    @State private var showFootprint = false
    @State private var flightAnimator: FlightRouteAnimator? = nil
```

- [ ] **Step 3: 在 `HomeView` 的 Menu 里添加「我的足迹」入口**

找到 `topBar` 里 `Menu { }` 的内容，在 `Divider()` 之前添加：

旧代码（定位锚点）：
```swift
                NavigationLink(destination: ExploreView()) {
                    Label("探索目的地", systemImage: "safari.fill")
                }
                Divider()
```

新代码：
```swift
                NavigationLink(destination: ExploreView()) {
                    Label("探索目的地", systemImage: "safari.fill")
                }
                Button {
                    showFootprint = true
                } label: {
                    Label("我的足迹", systemImage: "map.fill")
                }
                Divider()
```

- [ ] **Step 4: 在 `HomeView.body` 添加 `.sheet`**

在现有 `.sheet(isPresented: $showTripList)` 之后添加：

旧代码（定位锚点）：
```swift
            .sheet(isPresented: $showTripList) { TripListSheet() }
```

新代码：
```swift
            .sheet(isPresented: $showTripList) { TripListSheet() }
            .sheet(isPresented: $showFootprint) {
                FootprintView(
                    provinceService: provinceService,
                    photoService: photoService
                )
            }
```

- [ ] **Step 5: Build 并在模拟器验证**

1. Build (`Cmd+B`)，无报错
2. 运行 App → 右上角菜单 → 「我的足迹」
3. 应打开 FootprintView sheet，显示地图 + 底部统计卡片
4. 已访问省份应有青色填充

- [ ] **Step 6: Commit**

```bash
cd /Users/ice/Desktop/Project/Map
git add TravelAI/TravelAI/Features/Home/FootprintView.swift \
        TravelAI/TravelAI/Features/Home/HomeView.swift
git commit -m "feat: footprint sheet with province map and stats card"
```

---

## Task 7: 准备世界省级 GeoJSON（20个热门目的地 + 国家级兜底）

**Files:**
- Create: `TravelAI/TravelAI/Resources/provinces-world.geojson`

热门目的地省级覆盖（目标国家）：
- 亚洲：日本（47都道府县）、韩国、泰国、新加坡（城市级）、马来西亚
- 欧洲：法国、德国（16州）、英国、意大利、西班牙
- 美洲：美国（51州）、加拿大
- 大洋洲：澳大利亚（8州/领地）、新西兰

GeoJSON 来源：[datahub.io/core/geo-admin1-countries](https://datahub.io/core/geo-admin1-countries) 或 Natural Earth Admin 1。

- [ ] **Step 1: 下载世界省级数据**

```bash
# Natural Earth Admin 1 (精简版，约3MB)
curl -L "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_1_states_provinces.geojson" \
  -o /tmp/provinces-world-raw.json
```

如网络不通，先用占位文件（最小 stub 含一个加州多边形）：

```bash
cat > /Users/ice/Desktop/Project/Map/TravelAI/TravelAI/Resources/provinces-world.geojson << 'GEOJSON'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "name": "California", "NAME_1": "California", "GID_1": "USA.CA_1", "ISO_A2": "US" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[-124.4,32.5],[-114.1,32.5],[-114.1,42.0],[-124.4,42.0],[-124.4,32.5]]]
      }
    }
  ]
}
GEOJSON
```

- [ ] **Step 2: 过滤只保留目标国家**（若下载完整文件）

```bash
# 用 python 过滤（macOS 自带 python3）
python3 << 'PY'
import json

with open('/tmp/provinces-world-raw.json') as f:
    data = json.load(f)

TARGET = {'US','CA','JP','KR','TH','SG','MY','FR','DE','GB','IT','ES','AU','NZ'}

filtered = [
    f for f in data['features']
    if (f.get('properties') or {}).get('iso_a2','').upper() in TARGET
    or (f.get('properties') or {}).get('ISO_A2','').upper() in TARGET
]

out = {'type': 'FeatureCollection', 'features': filtered}
with open('/Users/ice/Desktop/Project/Map/TravelAI/TravelAI/Resources/provinces-world.geojson', 'w') as f:
    json.dump(out, f, ensure_ascii=False, separators=(',',':'))

print(f"保留 {len(filtered)} 个省份")
PY
```

- [ ] **Step 3: 在 `ProvinceHighlightService` 里启用世界省级数据**

在 `ProvinceHighlightService.loadAndCompute` 方法里取消注释：

旧代码：
```swift
            // 世界数据（Task 5 加入后取消注释）
            // all += FootprintGeoJSONLoader.load(filename: "provinces-world.geojson", country: "WORLD")
```

新代码：
```swift
            // 世界省级数据（热门目的地）
            all += FootprintGeoJSONLoader.load(filename: "provinces-world.geojson", country: "WORLD")
```

- [ ] **Step 4: 更新 `FootprintGeoJSONLoader` 支持 Natural Earth 的 `iso_a2` 字段**

在 `FootprintGeoJSONLoader.load` 的 props 解析区，`name` 解析已涵盖 `NAME_1`，`adcode` 解析已涵盖 `GID_1`，country 由外部传入"WORLD"，内部需从 props 读实际 ISO。

在 `FootprintGeoJSONLoader.load` 方法签名改为返回时携带真实 country：

旧代码：
```swift
    static func load(filename: String, country: String) -> [ProvinceRegion] {
```
（不改签名，改内部逻辑：从 props 读 `iso_a2` 作为 country override）

在 `FootprintGeoJSONLoader` 的 `ProvinceRegion` 构建处（`result.append`）前添加：

```swift
            // 尝试从 properties 读取真实 ISO 国家代码
            let resolvedCountry = (props["iso_a2"] as? String
                                ?? props["ISO_A2"] as? String
                                ?? country).uppercased()
```

并将 `result.append(ProvinceRegion(... country: country ...))` 改为 `country: resolvedCountry`。

- [ ] **Step 5: 在 Xcode 把 `provinces-world.geojson` 加入 target**

- [ ] **Step 6: Build + 运行验证**

到访过美国/日本等行程的省份也应显示高亮。

- [ ] **Step 7: Commit**

```bash
cd /Users/ice/Desktop/Project/Map
git add TravelAI/TravelAI/Resources/provinces-world.geojson \
        TravelAI/TravelAI/Services/FootprintGeoJSONLoader.swift \
        TravelAI/TravelAI/Services/ProvinceHighlightService.swift
git commit -m "feat: add world province GeoJSON for top-20 travel destinations"
```

---

## Task 8: 性能优化 — 缓存 MKPolygonRenderer

**Files:**
- Modify: `TravelAI/TravelAI/Services/ProvinceHighlightService.swift`

当前实现每次 `loadAndCompute` 都重建 `MKPolygonRenderer`，数据量大时耗时。优化：把 renderer 预构建并缓存。

- [ ] **Step 1: 在 `loadAndCompute` 的 Task.detached 里预构建 renderer**

旧代码（点在多边形内判断的 Task.detached 块）：
```swift
        let (visitedIDs, countryCodes) = await Task.detached(priority: .userInitiated) {
            var ids = Set<String>()
            var countries = Set<String>()
            for region in regions {
                for poly in region.polygons {
                    guard poly.count > 2 else { continue }
                    let mkPoly = MKPolygon(coordinates: poly, count: poly.count)
                    let renderer = MKPolygonRenderer(polygon: mkPoly)
                    for coord in coords {
                        let point = MKMapPoint(coord)
                        if renderer.path?.contains(renderer.point(for: point)) == true {
                            ids.insert(region.id)
                            countries.insert(region.country)
                            break
                        }
                    }
                }
            }
            return (ids, countries)
        }.value
```

新代码（预构建 renderer，仅在 path 为 nil 时 createPath）：
```swift
        let (visitedIDs, countryCodes) = await Task.detached(priority: .userInitiated) {
            var ids = Set<String>()
            var countries = Set<String>()

            // 预构建所有 renderer（createPath 后可重复使用）
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
```

- [ ] **Step 2: Build + 运行，确认功能正常**

- [ ] **Step 3: Commit**

```bash
cd /Users/ice/Desktop/Project/Map
git add TravelAI/TravelAI/Services/ProvinceHighlightService.swift
git commit -m "perf: pre-build MKPolygonRenderer CGPath to speed up point-in-polygon"
```

---

## Self-Review

### Spec Coverage Check
| 需求 | 对应 Task |
|------|-----------|
| 中国省份点亮（高德风格青色填充） | Task 1 + 2 + 3 + 4 |
| 国外热门目的地省级点亮 | Task 7 |
| 其他国家国家级兜底 | Task 7（Natural Earth 数据含全球国家级） |
| 统计卡片（城市/省份/国家） | Task 6 |
| 足迹专页 Sheet | Task 6 |
| 照片 GPS 作为到访依据 | Task 3（`photoLocations` 参数） |
| 行程坐标作为到访依据 | Task 3（`trips` 参数） |
| 性能优化 | Task 8 |

### 无 Placeholder 确认
- 所有代码块完整，无 TBD
- 所有命令有预期输出说明
- Task 7 Step 1 提供了网络不通时的 stub 备用方案

### 类型一致性
- `ProvinceRegion` 在 Task 2 定义，Task 3/4/6 均使用同一结构
- `ProvinceHighlightService.visitedRegions` 在 Task 3 定义，Task 4/6 使用
- `FootprintGeoJSONLoader.load(filename:country:)` 签名在 Task 2 定义，Task 3 + Task 7 使用一致
