import SwiftUI
import MapKit
import CoreLocation

// MARK: - 飞行轨迹动画状态
@Observable
final class FlightRouteAnimator {

    var isAnimating = false
    var currentPhase: AnimPhase = .idle
    var drawnPoints: [CLLocationCoordinate2D] = []
    var planePosition: CLLocationCoordinate2D? = nil
    var planeHeading: Double = 0
    var transportMode: TransportMode = .plane        // 当前动画出行方式
    var mapCameraPosition: MapCameraPosition = .automatic
    var visibleAnnotations: [RouteAnnotation] = []

    enum AnimPhase: Equatable {
        case idle
        case toHub          // 前往出发枢纽（机场/高铁站/上车点）
        case enRoute        // 途中（飞行弧线 / 高铁直线 / 驾车直线）
        case arriveDestination
        case itineraryDay(Int)
        case done
    }

    // MARK: - 预览入口
    func startPreview(
        origin: CLLocationCoordinate2D,
        destinationName: String,
        mode: TransportMode
    ) async {
        guard !isAnimating else { return }
        isAnimating = true
        transportMode = mode
        drawnPoints = []
        visibleAnnotations = []

        // 1. geocode 目的地
        let destination = await geocode(destinationName) ?? fallbackCoordinate(from: origin)
        let totalDist = greatCircleDistance(origin, destination)

        // 2. geocode 出发枢纽（用用户位置城市名查，AI 查询，失败退回 origin）
        // 出发地用 origin 坐标反推城市名，或直接用"当前位置附近"
        let hubLabel: String
        let hubIcon: String
        let departureHubQuery: String
        switch mode {
        case .plane:
            departureHubQuery = "出发地附近机场"  // 出发地坐标已知，直接用 origin fallback
            hubLabel = "✈ 出发机场"
            hubIcon  = "airplane"
        case .train:
            departureHubQuery = "出发地高铁站"
            hubLabel = "🚄 高铁站"
            hubIcon  = "tram.fill"
        case .drive:
            departureHubQuery = ""
            hubLabel = ""
            hubIcon  = ""
        }

        // 出发枢纽：直接用 origin（用户当前位置），不额外 geocode
        // 原因：AI 不知道用户具体在哪个城市，geocode "出发地附近机场" 无意义
        let departureHub = origin

        // 3. geocode 到达枢纽
        let arrivalQuery: String
        let arrivalLabel: String
        switch mode {
        case .plane:  arrivalQuery = "\(destinationName)国际机场"; arrivalLabel = "✈ 到达机场"
        case .train:  arrivalQuery = "\(destinationName)高铁站";   arrivalLabel = "🚄 到达高铁站"
        case .drive:  arrivalQuery = ""; arrivalLabel = ""
        }

        let arrivalHub: CLLocationCoordinate2D
        if mode == .drive {
            arrivalHub = destination
        } else if let (lat, lon) = await AIService.geocode(arrivalQuery) {
            arrivalHub = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            arrivalHub = destination
        }

        // 4. 开场俯视
        await animateCamera(to: .camera(MapCamera(
            centerCoordinate: midpoint(origin, destination),
            distance: max(totalDist * 2.5, 4_000_000),
            heading: 0, pitch: 0
        )), duration: 1.2)
        try? await Task.sleep(for: .milliseconds(400))

        // 俯冲到出发地
        await animateCamera(to: .camera(MapCamera(
            centerCoordinate: origin,
            distance: max(totalDist * 0.08, 120_000),
            heading: bearing(from: origin, to: departureHub),
            pitch: 60
        )), duration: 1.0)

        // 5. 前往出发枢纽（驾车模式跳过）
        await MainActor.run { currentPhase = .toHub }
        if mode != .drive && departureHub.latitude != origin.latitude {
            await animatePolyline(from: origin, to: departureHub, steps: 20, stepDelay: 0.04, style: .ground)
            addAnnotation(RouteAnnotation(coordinate: departureHub, label: hubLabel,
                                          type: .hub(icon: hubIcon)))
            try? await Task.sleep(for: .milliseconds(300))
        }

        // 6. 主要路段
        await MainActor.run { currentPhase = .enRoute }
        switch mode {
        case .plane:
            await animateGreatCircle(from: departureHub, to: arrivalHub, steps: 80)
        case .train:
            await animateTrainRoute(from: departureHub, to: arrivalHub)
        case .drive:
            await animateDriveRoute(from: origin, to: destination)
        }

        // 7. 到达
        await MainActor.run { currentPhase = .arriveDestination }
        if mode != .drive {
            addAnnotation(RouteAnnotation(coordinate: arrivalHub, label: arrivalLabel,
                                          type: .hub(icon: mode == .plane ? "airplane" : "tram.fill")))
        }
        addAnnotation(RouteAnnotation(coordinate: destination, label: destinationName, type: .destination))
        await animateCamera(to: .camera(MapCamera(
            centerCoordinate: destination,
            distance: 600_000, heading: 0, pitch: 30
        )), duration: 1.0)
    }

    // MARK: - 坐标字符串（给 AI geocode 用）
    private func coordString(_ c: CLLocationCoordinate2D) -> String {
        "\(String(format:"%.2f",c.latitude)),\(String(format:"%.2f",c.longitude))"
    }

    // MARK: - 高铁动画（地面曲线，速度快，图标🚄）
    private func animateTrainRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async {
        let dist = greatCircleDistance(from, to)
        let steps = 60
        let segBearing = bearing(from: from, to: to)
        for step in 1...steps {
            let t = Double(step) / Double(steps)
            // 高铁走大圆路线但贴地（用球面插值，不抬高弧度）
            let pt = greatCircleInterpolate(from, to, t: t)
            let hdg = greatCircleBearing(from: from, to: to, t: t)
            await MainActor.run {
                drawnPoints.append(pt)
                planePosition = pt
                planeHeading = hdg
            }
            if step % 6 == 0 || step == steps {
                let cam = MapCamera(
                    centerCoordinate: pt,
                    distance: max(dist * 0.5, 600_000),
                    heading: segBearing, pitch: 35
                )
                await MainActor.run { withAnimation(.linear(duration: 0.18)) { mapCameraPosition = .camera(cam) } }
            }
            try? await Task.sleep(for: .milliseconds(28))
        }
    }

    // MARK: - 驾车动画（地面直线，较慢，图标🚗）
    private func animateDriveRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async {
        let dist = greatCircleDistance(from, to)
        let steps = 50
        let segBearing = bearing(from: from, to: to)
        for step in 1...steps {
            let t = Double(step) / Double(steps)
            let pt = interpolate(from, to, t: t)
            await MainActor.run {
                drawnPoints.append(pt)
                planePosition = pt
                planeHeading = segBearing
            }
            if step % 5 == 0 || step == steps {
                let cam = MapCamera(
                    centerCoordinate: pt,
                    distance: max(dist * 0.45, 200_000),
                    heading: segBearing, pitch: 45
                )
                await MainActor.run { withAnimation(.linear(duration: 0.14)) { mapCameraPosition = .camera(cam) } }
            }
            try? await Task.sleep(for: .milliseconds(40))
        }
    }

    // MARK: - 接续行程路线（AI 完成后调用）
    func continueWithItinerary(itinerary: [[CLLocationCoordinate2D]]) async {
        // 等路线动画到达目的地（最多等 30s，兼容飞机/高铁/驾车三种模式）
        var waited = 0
        while currentPhase != .arriveDestination && currentPhase != .done && currentPhase != .idle && waited < 60 {
            try? await Task.sleep(for: .milliseconds(500))
            waited += 1
        }

        for (dayIdx, coords) in itinerary.enumerated() where coords.count >= 2 {
            await MainActor.run { currentPhase = .itineraryDay(dayIdx) }
            let center = centroid(coords)
            let span = boundingSpan(coords)
            await animateCamera(to: .camera(MapCamera(
                centerCoordinate: center,
                distance: span * 80_000,
                heading: 0, pitch: 20
            )), duration: 0.8)

            for i in 0..<(coords.count - 1) {
                await animatePolyline(from: coords[i], to: coords[i + 1], steps: 16, stepDelay: 0.035, style: .itinerary(day: dayIdx))
                addAnnotation(RouteAnnotation(coordinate: coords[i], label: "Day \(dayIdx + 1) · \(i + 1)", type: .waypoint(day: dayIdx)))
                try? await Task.sleep(for: .milliseconds(150))
            }
            if let last = coords.last {
                addAnnotation(RouteAnnotation(coordinate: last, label: "Day \(dayIdx + 1) · \(coords.count)", type: .waypoint(day: dayIdx)))
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

        await MainActor.run {
            currentPhase = .done
            planePosition = nil
            isAnimating = false
        }
    }

    // MARK: - 主入口（向后兼容）
    func start(
        origin: CLLocationCoordinate2D,
        destinationName: String,
        mode: TransportMode = .plane,
        itinerary: [[CLLocationCoordinate2D]]
    ) async {
        await startPreview(origin: origin, destinationName: destinationName, mode: mode)
        await continueWithItinerary(itinerary: itinerary)
    }

    // MARK: - 折线动画（地面 / 行程）
    private enum LineStyle { case ground, itinerary(day: Int) }

    private func animatePolyline(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        steps: Int,
        stepDelay: Double,
        style: LineStyle
    ) async {
        let segBearing = bearing(from: from, to: to)
        let dist = greatCircleDistance(from, to)
        for step in 1...steps {
            let t = Double(step) / Double(steps)
            let pt = interpolate(from, to, t: t)
            await MainActor.run {
                drawnPoints.append(pt)
                planePosition = pt
                planeHeading = segBearing
            }
            // 地面段镜头低角度跟随（pitch=30，距离近）
            if step % 5 == 0 || step == steps {
                let camDist = max(dist * 0.6, 80_000.0)
                let cam = MapCamera(
                    centerCoordinate: pt,
                    distance: camDist,
                    heading: segBearing,
                    pitch: 30
                )
                await MainActor.run {
                    withAnimation(.linear(duration: 0.12)) {
                        mapCameraPosition = .camera(cam)
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(Int(stepDelay * 1000)))
        }
    }

    // MARK: - 大圆弧线动画（飞行）
    private func animateGreatCircle(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        steps: Int
    ) async {
        let dist = greatCircleDistance(from, to)
        // 根据距离决定飞行高度（镜头距离）
        let cruiseAlt = max(dist * 0.55, 1_800_000.0)
        let totalSteps = steps

        for step in 1...totalSteps {
            let t = Double(step) / Double(totalSteps)
            let pt = greatCircleInterpolate(from, to, t: t)
            let heading = greatCircleBearing(from: from, to: to, t: t)

            await MainActor.run {
                drawnPoints.append(pt)
                planePosition = pt
                planeHeading = heading
            }

            // 镜头：随飞机移动，飞行中保持倾斜跟随
            // 每10步更新一次镜头（避免过于频繁）
            if step % 8 == 0 || step == 1 || step == totalSteps {
                let pitch: Double
                let camDist: Double
                if t < 0.12 {
                    // 起飞：镜头从正上方逐渐倾斜
                    pitch = t / 0.12 * 50
                    camDist = cruiseAlt * (1.5 - t * 0.5)
                } else if t > 0.88 {
                    // 降落：镜头逐渐压低
                    pitch = 50 * (1 - (t - 0.88) / 0.12)
                    camDist = cruiseAlt * (1 + (t - 0.88) * 3)
                } else {
                    // 巡航：固定俯仰跟随
                    pitch = 50
                    camDist = cruiseAlt
                }
                let cam = MapCamera(
                    centerCoordinate: pt,
                    distance: camDist,
                    heading: heading,
                    pitch: pitch
                )
                await MainActor.run {
                    withAnimation(.linear(duration: 0.15)) {
                        mapCameraPosition = .camera(cam)
                    }
                }
            }

            // 中段加速，起降减速
            let delay: Double
            if step < 12 || step > totalSteps - 12 { delay = 0.06 }
            else if step < 20 || step > totalSteps - 20 { delay = 0.035 }
            else { delay = 0.022 }
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
        }
    }

    // MARK: - 镜头动画
    private func animateCamera(to position: MapCameraPosition, duration: Double) async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: duration)) {
                mapCameraPosition = position
            }
        }
        try? await Task.sleep(for: .milliseconds(Int(duration * 1000) + 200))
    }

    // MARK: - 添加标注
    private func addAnnotation(_ annotation: RouteAnnotation) {
        Task { @MainActor in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                visibleAnnotations.append(annotation)
            }
        }
    }

    // MARK: - 几何工具
    private func interpolate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, t: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude:  a.latitude  + (b.latitude  - a.latitude)  * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    private func greatCircleInterpolate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, t: Double) -> CLLocationCoordinate2D {
        // 球面线性插值（SLERP 简化版）
        let lat1 = a.latitude  * .pi / 180
        let lon1 = a.longitude * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let lon2 = b.longitude * .pi / 180

        let d = 2 * asin(sqrt(pow(sin((lat2 - lat1) / 2), 2) + cos(lat1) * cos(lat2) * pow(sin((lon2 - lon1) / 2), 2)))
        guard d > 0.0001 else { return interpolate(a, b, t: t) }

        let A = sin((1 - t) * d) / sin(d)
        let B = sin(t * d) / sin(d)

        let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
        let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
        let z = A * sin(lat1) + B * sin(lat2)

        let lat = atan2(z, sqrt(x * x + y * y))
        let lon = atan2(y, x)

        return CLLocationCoordinate2D(latitude: lat * 180 / .pi, longitude: lon * 180 / .pi)
    }

    private func greatCircleBearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D, t: Double) -> Double {
        let mid = greatCircleInterpolate(a, b, t: min(t + 0.01, 1.0))
        return bearing(from: greatCircleInterpolate(a, b, t: t), to: mid)
    }

    private func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude  * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func midpoint(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude:  (a.latitude  + b.latitude)  / 2,
            longitude: (a.longitude + b.longitude) / 2
        )
    }

    private func greatCircleDistance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6_371_000.0
        let lat1 = a.latitude  * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let dLat = (b.latitude  - a.latitude)  * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let aa = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return R * 2 * atan2(sqrt(aa), sqrt(1 - aa))
    }

    private func centroid(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let avgLat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let avgLon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }

    private func boundingSpan(_ coords: [CLLocationCoordinate2D]) -> Double {
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let dlat = (lats.max() ?? 0) - (lats.min() ?? 0)
        let dlon = (lons.max() ?? 0) - (lons.min() ?? 0)
        return max(dlat, dlon, 0.2)
    }

    // MARK: - 内置精确坐标表
    // 覆盖主要旅游目的地，坐标均为城市/地区中心点。
    // 不依赖任何外部网络，彻底解决 Nominatim(GFW屏蔽) 和 Apple Maps(返回错误坐标) 的问题。
    // lat/lon 均来自 WGS-84，精度到小数点后两位。
    private static let coordTable: [String: CLLocationCoordinate2D] = {
        func c(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return [
            // ── 日本 ──────────────────────────────────────────────
            "东京":    c(35.68, 139.69), "Tokyo":   c(35.68, 139.69),
            "京都":    c(35.01, 135.77), "Kyoto":   c(35.01, 135.77),
            "大阪":    c(34.69, 135.50), "Osaka":   c(34.69, 135.50),
            "北海道":  c(43.06, 141.35), "Hokkaido":c(43.06, 141.35),
            "冲绳":    c(26.21, 127.68), "Okinawa": c(26.21, 127.68),
            "奈良":    c(34.68, 135.83), "Nara":    c(34.68, 135.83),
            "镰仓":    c(35.32, 139.55), "Kamakura":c(35.32, 139.55),
            "福冈":    c(33.59, 130.40), "广岛":    c(34.39, 132.45),
            // ── 韩国 ──────────────────────────────────────────────
            "首尔":    c(37.57, 126.98), "Seoul":   c(37.57, 126.98),
            "釜山":    c(35.18, 129.08), "Busan":   c(35.18, 129.08),
            "济州岛":  c(33.49, 126.53),
            // ── 中国港澳台 ────────────────────────────────────────
            "台北":    c(25.05, 121.53), "香港":    c(22.32, 114.17),
            "澳门":    c(22.19, 113.55),
            // ── 中国大陆城市 ──────────────────────────────────────
            "北京":    c(39.91, 116.39), "上海":    c(31.23, 121.47),
            "广州":    c(23.13, 113.26), "深圳":    c(22.54, 114.06),
            "成都":    c(30.57, 104.07), "重庆":    c(29.56, 106.55),
            "西安":    c(34.27, 108.95), "杭州":    c(30.25, 120.16),
            "南京":    c(32.06, 118.79), "武汉":    c(30.59, 114.31),
            "厦门":    c(24.48, 118.09), "青岛":    c(36.07, 120.38),
            "丽江":    c(26.87, 100.22), "三亚":    c(18.25, 109.51),
            "张家界":  c(29.12, 110.48), "黄山":    c(30.13, 118.16),
            "桂林":    c(25.27, 110.28), "西藏":    c(29.65,  91.13),
            "拉萨":    c(29.65,  91.13), "新疆":    c(43.79,  87.60),
            "乌鲁木齐":c(43.79,  87.60), "哈尔滨":  c(45.80, 126.54),
            "长沙":    c(28.23, 112.94), "昆明":    c(25.05, 102.72),
            "贵阳":    c(26.65, 106.63), "兰州":    c(36.06, 103.83),
            "苏州":    c(31.30, 120.60), "扬州":    c(32.40, 119.41),
            "洛阳":    c(34.68, 112.45), "开封":    c(34.80, 114.31),
            // ── 东南亚 ────────────────────────────────────────────
            "新加坡":  c( 1.35, 103.82), "Singapore":c(1.35, 103.82),
            "曼谷":    c(13.75, 100.52), "Bangkok": c(13.75, 100.52),
            "清迈":    c(18.79,  98.98), "普吉岛":  c( 7.89,  98.30),
            "河内":    c(21.03, 105.83), "Hanoi":   c(21.03, 105.83),
            "胡志明市":c(10.82, 106.63), "岘港":    c(16.05, 108.22),
            "会安":    c(15.88, 108.34), "吉隆坡":  c( 3.14, 101.69),
            "槟城":    c( 5.41, 100.34), "巴厘岛":  c(-8.34, 115.09),
            "雅加达":  c(-6.21, 106.85), "马尼拉":  c(14.60, 120.98),
            "金边":    c(11.56, 104.92), "仰光":    c(16.87,  96.19),
            // ── 南亚 ──────────────────────────────────────────────
            "孟买":    c(19.08,  72.88), "Mumbai":  c(19.08,  72.88),
            "德里":    c(28.61,  77.21), "Delhi":   c(28.61,  77.21),
            "斋浦尔":  c(26.91,  75.79), "加德满都":c(27.71,  85.31),
            "科伦坡":  c( 6.93,  79.85), "马累":    c( 4.18,  73.51),
            "廷布":    c(27.47,  89.64),
            // ── 中东 ──────────────────────────────────────────────
            "迪拜":    c(25.20,  55.27), "Dubai":   c(25.20,  55.27),
            "阿布扎比":c(24.47,  54.37), "伊斯坦布尔":c(41.01,28.96),
            "Istanbul":c(41.01,  28.96), "土耳其":  c(39.00,  35.24),
            "Turkey":  c(39.00,  35.24), "开罗":    c(30.05,  31.25),
            "Cairo":   c(30.05,  31.25), "卢克索":  c(25.69,  32.64),
            "特拉维夫":c(32.08,  34.78), "耶路撒冷":c(31.77,  35.22),
            "安曼":    c(31.95,  35.93), "佩特拉":  c(30.33,  35.44),
            "第比利斯":c(41.69,  44.83),
            // ── 欧洲 ──────────────────────────────────────────────
            "巴黎":    c(48.86,   2.35), "Paris":   c(48.86,   2.35),
            "法国":    c(46.23,   2.21), "伦敦":    c(51.51,  -0.13),
            "London":  c(51.51,  -0.13), "英国":    c(54.00,  -2.00),
            "罗马":    c(41.90,  12.48), "Rome":    c(41.90,  12.48),
            "米兰":    c(45.46,   9.19), "威尼斯":  c(45.44,  12.32),
            "佛罗伦萨":c(43.77,  11.25), "那不勒斯":c(40.85,  14.27),
            "意大利":  c(41.87,  12.57), "巴塞罗那":c(41.39,   2.15),
            "Barcelona":c(41.39,  2.15), "马德里":  c(40.42,  -3.70),
            "塞维利亚":c(37.39,  -5.99), "西班牙":  c(40.00,  -4.00),
            "里斯本":  c(38.72,  -9.14), "波尔图":  c(41.15,  -8.61),
            "葡萄牙":  c(39.40,  -8.22), "阿姆斯特丹":c(52.37, 4.90),
            "荷兰":    c(52.13,   5.29), "柏林":    c(52.52,  13.40),
            "慕尼黑":  c(48.14,  11.58), "汉堡":    c(53.55,   9.99),
            "法兰克福":c(50.11,   8.68), "德国":    c(51.17,  10.45),
            "维也纳":  c(48.21,  16.37), "Vienna":  c(48.21,  16.37),
            "奥地利":  c(47.52,  14.55), "布拉格":  c(50.08,  14.44),
            "Prague":  c(50.08,  14.44), "捷克":    c(49.82,  15.47),
            "布达佩斯":c(47.50,  19.04), "匈牙利":  c(47.16,  19.50),
            "华沙":    c(52.23,  21.01), "波兰":    c(51.92,  19.14),
            "雅典":    c(37.98,  23.73), "Athens":  c(37.98,  23.73),
            "圣托里尼":c(36.39,  25.46), "希腊":    c(39.07,  21.82),
            "苏黎世":  c(47.38,   8.54), "瑞士":    c(46.82,   8.23),
            "布鲁塞尔":c(50.85,   4.35), "比利时":  c(50.50,   4.47),
            "斯德哥尔摩":c(59.33, 18.07), "瑞典":   c(60.13,  18.64),
            "奥斯陆":  c(59.91,  10.75), "挪威":    c(64.55,  17.55),
            "赫尔辛基":c(60.17,  24.94), "芬兰":    c(61.92,  25.75),
            "哥本哈根":c(55.68,  12.57), "丹麦":    c(56.26,   9.50),
            "都柏林":  c(53.33,  -6.25), "爱尔兰":  c(53.14,  -7.69),
            "冰岛":    c(64.96, -19.02), "雷克雅未克":c(64.13,-21.84),
            "莫斯科":  c(55.75,  37.62), "圣彼得堡":c(59.95,  30.32),
            "俄罗斯":  c(61.52,  105.32),"克罗地亚":c(45.10,  15.20),
            "杜布罗夫尼克":c(42.65, 18.09),
            // ── 非洲 ──────────────────────────────────────────────
            "摩洛哥":  c(31.79,  -7.09), "Morocco": c(31.79,  -7.09),
            "马拉喀什":c(31.63,  -7.99), "菲斯":    c(34.04,  -5.00),
            "开普敦":  c(-33.93, 18.42), "Cape Town":c(-33.93,18.42),
            "约翰内斯堡":c(-26.20, 28.04),"南非":   c(-30.56, 22.94),
            "内罗毕":  c(-1.29,  36.82), "肯尼亚":  c( 0.02,  37.91),
            "坦桑尼亚":c(-6.37,  34.89), "突尼斯":  c(33.89,   9.54),
            "纳米比亚":c(-22.96, 18.49), "埃及":    c(26.82,  30.80),
            // ── 美洲 ──────────────────────────────────────────────
            "纽约":    c(40.71, -74.01), "New York":c(40.71, -74.01),
            "洛杉矶":  c(34.05,-118.24), "旧金山":  c(37.77,-122.42),
            "拉斯维加斯":c(36.17,-115.14),"迈阿密": c(25.77, -80.19),
            "芝加哥":  c(41.88, -87.63), "波士顿":  c(42.36, -71.06),
            "西雅图":  c(47.61,-122.33), "美国":    c(37.09, -95.71),
            "温哥华":  c(49.25,-123.12), "多伦多":  c(43.65, -79.38),
            "加拿大":  c(56.13, -106.35),"里约":    c(-22.91, -43.17),
            "布宜诺斯艾利斯":c(-34.61,-58.38),"利马":c(-12.05,-77.04),
            "墨西哥城":c(19.43, -99.13), "墨西哥":  c(23.63, -102.55),
            "巴西":    c(-14.24, -51.93),"阿根廷":  c(-38.42, -63.62),
            "智利":    c(-35.68, -71.54),"哥伦比亚":c( 4.57,  -74.30),
            "古巴":    c(21.52, -77.78), "秘鲁":    c(-9.19,  -75.02),
            // ── 大洋洲 ────────────────────────────────────────────
            "悉尼":    c(-33.87, 151.21), "Sydney": c(-33.87, 151.21),
            "墨尔本":  c(-37.81, 144.96), "澳大利亚":c(-25.27, 133.78),
            "奥克兰":  c(-36.85, 174.76), "新西兰":  c(-40.90, 174.89),
        ]
    }()

    /// 地名 → 坐标
    /// 1. 内置坐标表精确匹配（~160 个常见目的地，零延迟）
    /// 2. 内置坐标表模糊匹配
    /// 3. AI geocode（覆盖任意目的地，1-2s）
    private func geocode(_ name: String) async -> CLLocationCoordinate2D? {
        let key = name.trimmingCharacters(in: .whitespaces)

        // 精确匹配
        if let coord = Self.coordTable[key] {
            AILogger.shared.log("geocode hit(table): '\(key)' → \(String(format:"%.2f",coord.latitude)),\(String(format:"%.2f",coord.longitude))")
            return coord
        }
        // 模糊匹配
        for (tableKey, coord) in Self.coordTable {
            if key.contains(tableKey) || tableKey.contains(key) {
                AILogger.shared.log("geocode hit(fuzzy '\(tableKey)'): '\(key)' → \(String(format:"%.2f",coord.latitude)),\(String(format:"%.2f",coord.longitude))")
                return coord
            }
        }

        // AI geocode fallback
        AILogger.shared.log("geocode table miss '\(key)', asking AI...")
        if let (lat, lon) = await AIService.geocode(key) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        AILogger.shared.log("geocode failed for '\(key)'")
        return nil
    }

    /// 找不到坐标时的保底：在 origin 的正东方 1000km 处
    private func fallbackCoordinate(from origin: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: origin.latitude, longitude: min(origin.longitude + 9, 170))
    }
}

// MARK: - 路线标注模型
struct RouteAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let label: String
    let type: AnnotationType

    enum AnnotationType {
        case hub(icon: String)   // 机场 / 高铁站 / 上车点
        case destination
        case waypoint(day: Int)
    }

    var color: Color {
        switch type {
        case .hub:         return Color(hex: "#5ac8fa")
        case .destination: return Color(hex: "#ff9500")
        case .waypoint(let day):
            let colors: [Color] = [
                Color(hex: "#30d158"), Color(hex: "#007aff"),
                Color(hex: "#af52de"), Color(hex: "#ff2d55"),
                Color(hex: "#ff9f0a"), Color(hex: "#5ac8fa"),
                Color(hex: "#34c759")
            ]
            return colors[day % colors.count]
        }
    }

    var systemIcon: String {
        switch type {
        case .hub(let icon): return icon
        case .destination:   return "mappin.circle.fill"
        case .waypoint:      return "circle.fill"
        }
    }
}
