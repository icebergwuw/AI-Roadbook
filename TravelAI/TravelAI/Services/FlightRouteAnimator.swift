import SwiftUI
import MapKit
import CoreLocation

// MARK: - 飞行路线段
enum RouteSegmentType {
    case ground(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)  // 地面（去机场）
    case flight(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)  // 飞行弧线
    case itinerary(coords: [CLLocationCoordinate2D], day: Int)             // 行程路线
}

struct RouteSegment: Identifiable {
    let id = UUID()
    let type: RouteSegmentType
    let label: String
}

// MARK: - 飞行轨迹动画状态
@Observable
final class FlightRouteAnimator {

    var isAnimating = false
    var currentPhase: AnimPhase = .idle
    var drawnPoints: [CLLocationCoordinate2D] = []   // 正在绘制的折线点
    var planePosition: CLLocationCoordinate2D? = nil  // 飞机图标位置
    var planeHeading: Double = 0                       // 飞机朝向（度）
    var mapCameraPosition: MapCameraPosition = .automatic
    var visibleAnnotations: [RouteAnnotation] = []    // 已出现的地点标注

    enum AnimPhase: Equatable {
        case idle
        case flyingToAirport
        case inFlight
        case arriveDestination
        case itineraryDay(Int)
        case done
    }

    // MARK: - 预览入口（用户点击生成后立刻调用，只需目的地名字）
    /// 立刻开始飞行动画；AI 生成完成后调用 continueWithItinerary() 接续行程路线
    func startPreview(
        origin: CLLocationCoordinate2D,
        destinationName: String
    ) async {
        guard !isAnimating else { return }
        isAnimating = true
        drawnPoints = []
        visibleAnnotations = []

        // geocoding 目的地坐标
        let destination = await geocode(destinationName) ?? fallbackCoordinate(from: origin)
        let totalDist = greatCircleDistance(origin, destination)

        // 开场：先从高处俯视两点，再压低镜头到出发地
        await animateCamera(to: .camera(MapCamera(
            centerCoordinate: midpoint(origin, destination),
            distance: max(totalDist * 2.5, 4_000_000),
            heading: 0, pitch: 0
        )), duration: 1.2)

        try? await Task.sleep(for: .milliseconds(400))

        // 俯冲到出发地低角度
        await animateCamera(to: .camera(MapCamera(
            centerCoordinate: origin,
            distance: max(totalDist * 0.08, 120_000),
            heading: bearing(from: origin, to: destination),
            pitch: 60
        )), duration: 1.0)

        // 地面段：当前位置 → 机场
        await MainActor.run { currentPhase = .flyingToAirport }
        let nearestAirport = await findNearestAirport(near: origin) ?? origin
        await animatePolyline(from: origin, to: nearestAirport, steps: 20, stepDelay: 0.04, style: .ground)
        addAnnotation(RouteAnnotation(coordinate: nearestAirport, label: "✈ 出发机场", type: .airport))
        try? await Task.sleep(for: .milliseconds(300))

        // 飞行段：机场 → 目的地
        await MainActor.run { currentPhase = .inFlight }
        await animateGreatCircle(from: nearestAirport, to: destination, steps: 80)

        await MainActor.run { currentPhase = .arriveDestination }
        addAnnotation(RouteAnnotation(coordinate: destination, label: destinationName, type: .destination))

        await animateCamera(to: .camera(MapCamera(
            centerCoordinate: destination,
            distance: 600_000,
            heading: 0, pitch: 30
        )), duration: 1.0)

        // 在目的地悬停等待，直到 AI 完成或被 continueWithItinerary() 接管
        // isAnimating 保持 true，飞机停在目的地
    }

    // MARK: - 接续行程路线（AI 完成后调用）
    func continueWithItinerary(itinerary: [[CLLocationCoordinate2D]]) async {
        // 如果飞行动画还没到目的地，等它完成（最多等 10s）
        var waited = 0
        while currentPhase != .arriveDestination && currentPhase != .idle && waited < 20 {
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

    // MARK: - 主入口（完整流程，保留向后兼容）
    func start(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        destinationName: String,
        itinerary: [[CLLocationCoordinate2D]]
    ) async {
        await startPreview(origin: origin, destinationName: destinationName)
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

    // MARK: - 查找最近机场
    private func findNearestAirport(near coord: CLLocationCoordinate2D) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "airport"
        request.region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
        )
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let item = response.mapItems.first else { return nil }
        return item.placemark.coordinate
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

    // MARK: - 中文地名 → (英文搜索词, 预期ISO国家码)
    // 有国家码约束，geocode 结果必须匹配，彻底避免同名小镇（如美国的 Paris, TX）干扰
    private static let chineseToEnglish: [String: (query: String, country: String)] = [
        // 国家/地区
        "摩洛哥": ("Morocco", "MA"), "冰岛": ("Iceland", "IS"),
        "挪威": ("Norway", "NO"), "瑞典": ("Sweden", "SE"),
        "芬兰": ("Finland", "FI"), "丹麦": ("Denmark", "DK"),
        "希腊": ("Greece", "GR"), "西班牙": ("Spain", "ES"),
        "葡萄牙": ("Portugal", "PT"), "意大利": ("Italy", "IT"),
        "法国": ("France", "FR"), "德国": ("Germany", "DE"),
        "英国": ("United Kingdom", "GB"), "爱尔兰": ("Ireland", "IE"),
        "荷兰": ("Netherlands", "NL"), "比利时": ("Belgium", "BE"),
        "瑞士": ("Switzerland", "CH"), "奥地利": ("Austria", "AT"),
        "波兰": ("Poland", "PL"), "捷克": ("Czech Republic", "CZ"),
        "匈牙利": ("Hungary", "HU"), "克罗地亚": ("Croatia", "HR"),
        "俄罗斯": ("Russia", "RU"), "埃及": ("Egypt", "EG"),
        "南非": ("South Africa", "ZA"), "肯尼亚": ("Kenya", "KE"),
        "坦桑尼亚": ("Tanzania", "TZ"), "突尼斯": ("Tunisia", "TN"),
        "纳米比亚": ("Namibia", "NA"), "印度": ("India", "IN"),
        "泰国": ("Thailand", "TH"), "越南": ("Vietnam", "VN"),
        "柬埔寨": ("Cambodia", "KH"), "缅甸": ("Myanmar", "MM"),
        "尼泊尔": ("Nepal", "NP"), "斯里兰卡": ("Sri Lanka", "LK"),
        "马尔代夫": ("Maldives", "MV"), "不丹": ("Bhutan", "BT"),
        "印度尼西亚": ("Indonesia", "ID"), "菲律宾": ("Philippines", "PH"),
        "马来西亚": ("Malaysia", "MY"), "墨西哥": ("Mexico", "MX"),
        "巴西": ("Brazil", "BR"), "阿根廷": ("Argentina", "AR"),
        "智利": ("Chile", "CL"), "哥伦比亚": ("Colombia", "CO"),
        "古巴": ("Cuba", "CU"), "加拿大": ("Canada", "CA"),
        "澳大利亚": ("Australia", "AU"), "新西兰": ("New Zealand", "NZ"),
        "土耳其": ("Turkey", "TR"), "以色列": ("Israel", "IL"),
        "约旦": ("Jordan", "JO"), "格鲁吉亚": ("Georgia", "GE"),
        "秘鲁": ("Peru", "PE"), "巴厘岛": ("Bali", "ID"),
        // 城市
        "巴黎": ("Paris", "FR"),
        "伦敦": ("London", "GB"),
        "罗马": ("Rome", "IT"),
        "米兰": ("Milan", "IT"),
        "威尼斯": ("Venice", "IT"),
        "佛罗伦萨": ("Florence", "IT"),
        "那不勒斯": ("Naples", "IT"),
        "巴塞罗那": ("Barcelona", "ES"),
        "马德里": ("Madrid", "ES"),
        "塞维利亚": ("Seville", "ES"),
        "里斯本": ("Lisbon", "PT"),
        "波尔图": ("Porto", "PT"),
        "阿姆斯特丹": ("Amsterdam", "NL"),
        "柏林": ("Berlin", "DE"),
        "慕尼黑": ("Munich", "DE"),
        "汉堡": ("Hamburg", "DE"),
        "法兰克福": ("Frankfurt", "DE"),
        "维也纳": ("Vienna", "AT"),
        "布拉格": ("Prague", "CZ"),
        "布达佩斯": ("Budapest", "HU"),
        "华沙": ("Warsaw", "PL"),
        "雅典": ("Athens", "GR"),
        "圣托里尼": ("Santorini", "GR"),
        "迪拜": ("Dubai", "AE"),
        "阿布扎比": ("Abu Dhabi", "AE"),
        "伊斯坦布尔": ("Istanbul", "TR"),
        "开罗": ("Cairo", "EG"),
        "卢克索": ("Luxor", "EG"),
        "开普敦": ("Cape Town", "ZA"),
        "约翰内斯堡": ("Johannesburg", "ZA"),
        "内罗毕": ("Nairobi", "KE"),
        "圣彼得堡": ("Saint Petersburg", "RU"),
        "莫斯科": ("Moscow", "RU"),
        "纽约": ("New York", "US"),
        "洛杉矶": ("Los Angeles", "US"),
        "旧金山": ("San Francisco", "US"),
        "拉斯维加斯": ("Las Vegas", "US"),
        "迈阿密": ("Miami", "US"),
        "芝加哥": ("Chicago", "US"),
        "波士顿": ("Boston", "US"),
        "西雅图": ("Seattle", "US"),
        "温哥华": ("Vancouver", "CA"),
        "多伦多": ("Toronto", "CA"),
        "悉尼": ("Sydney", "AU"),
        "墨尔本": ("Melbourne", "AU"),
        "奥克兰": ("Auckland", "NZ"),
        "里约": ("Rio de Janeiro", "BR"),
        "布宜诺斯艾利斯": ("Buenos Aires", "AR"),
        "利马": ("Lima", "PE"),
        "墨西哥城": ("Mexico City", "MX"),
        "京都": ("Kyoto", "JP"),
        "东京": ("Tokyo", "JP"),
        "大阪": ("Osaka", "JP"),
        "北海道": ("Hokkaido", "JP"),
        "冲绳": ("Okinawa", "JP"),
        "奈良": ("Nara", "JP"),
        "镰仓": ("Kamakura", "JP"),
        "首尔": ("Seoul", "KR"),
        "釜山": ("Busan", "KR"),
        "济州岛": ("Jeju Island", "KR"),
        "台北": ("Taipei", "TW"),
        "香港": ("Hong Kong", "HK"),
        "澳门": ("Macau", "MO"),
        "新加坡": ("Singapore", "SG"),
        "曼谷": ("Bangkok", "TH"),
        "清迈": ("Chiang Mai", "TH"),
        "普吉岛": ("Phuket", "TH"),
        "河内": ("Hanoi", "VN"),
        "胡志明市": ("Ho Chi Minh City", "VN"),
        "岘港": ("Da Nang", "VN"),
        "会安": ("Hoi An", "VN"),
        "吉隆坡": ("Kuala Lumpur", "MY"),
        "槟城": ("Penang", "MY"),
        "雅加达": ("Jakarta", "ID"),
        "孟买": ("Mumbai", "IN"),
        "德里": ("Delhi", "IN"),
        "斋浦尔": ("Jaipur", "IN"),
        "加德满都": ("Kathmandu", "NP"),
        "科伦坡": ("Colombo", "LK"),
        "特拉维夫": ("Tel Aviv", "IL"),
        "耶路撒冷": ("Jerusalem", "IL"),
        "安曼": ("Amman", "JO"),
        "佩特拉": ("Petra", "JO"),
        "第比利斯": ("Tbilisi", "GE"),
    ]

    /// 地名 → 坐标
    /// 策略：
    ///   1. 有映射 → CLGeocoder(en_US) 搜 query，验证 isoCountryCode 必须匹配
    ///   2. 步骤1失败 → MKLocalSearch 用 query 搜，同样验证国家码
    ///   3. 无映射（中国城市）→ CLGeocoder 直接搜原名，不限国家
    private func geocode(_ name: String) async -> CLLocationCoordinate2D? {
        let entry = Self.chineseToEnglish[name]
        let searchQuery = entry?.query ?? name
        let expectedCountry = entry?.country
        AILogger.shared.log("geocode '\(name)' → '\(searchQuery)' expected=\(expectedCountry ?? "any")")

        // --- 步骤1：CLGeocoder en_US ---
        let r1: CLLocationCoordinate2D? = await withCheckedContinuation { cont in
            CLGeocoder().geocodeAddressString(searchQuery, in: nil,
                preferredLocale: Locale(identifier: "en_US")) { placemarks, _ in
                guard let mark = placemarks?.first, let loc = mark.location?.coordinate else {
                    cont.resume(returning: nil); return
                }
                let got = mark.isoCountryCode ?? ""
                AILogger.shared.log("CLGeocoder: '\(mark.name ?? "?")' \(got) lat=\(String(format:"%.3f",loc.latitude))")
                if let exp = expectedCountry, got != exp {
                    AILogger.shared.log("CLGeocoder rejected: expected \(exp) got \(got)")
                    cont.resume(returning: nil); return
                }
                cont.resume(returning: loc)
            }
        }
        if let r = r1 {
            AILogger.shared.log("geocode OK(CLGeocoder): \(String(format:"%.4f",r.latitude)),\(String(format:"%.4f",r.longitude))")
            return r
        }

        // --- 步骤2：MKLocalSearch fallback（仅当有映射时）---
        if entry != nil {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = searchQuery
            let r2 = try? await MKLocalSearch(request: req).start()
            if let item = r2?.mapItems.first(where: { mk in
                guard let exp = expectedCountry else { return true }
                return mk.placemark.isoCountryCode == exp
            }) {
                let loc = item.placemark.coordinate
                AILogger.shared.log("geocode OK(MKLocalSearch): \(String(format:"%.4f",loc.latitude)),\(String(format:"%.4f",loc.longitude))")
                return loc
            }
            AILogger.shared.log("geocode MKLocalSearch also failed for '\(name)'")
        }

        AILogger.shared.log("geocode failed for '\(name)'")
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
        case airport
        case destination
        case waypoint(day: Int)
    }

    var color: Color {
        switch type {
        case .airport:     return Color(hex: "#5ac8fa")
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
}
