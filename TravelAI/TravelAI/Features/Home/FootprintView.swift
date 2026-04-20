import SwiftUI
import MapKit
import SwiftData

struct FootprintView: View {
    @Environment(\.dismiss) private var dismiss
    var provinceService: ProvinceHighlightService
    var photoService: PhotoMemoryService

    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var showProvinceList = false

    // 城市数：从行程目的地去重统计
    private var visitedCityCount: Int {
        Set(trips.map { $0.destination }).count
    }

    // 国家数（至少1个如果有城市）
    private var countryCount: Int {
        max(provinceService.visitedCountryCount, visitedCityCount > 0 ? 1 : 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 地图背景（全屏）
                Map {
                    // 省份高亮（底层）
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

                // 底部覆盖层
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 统计卡片
                        statsCard
                        // 省份列表入口（有访问省份时显示）
                        if !provinceService.visitedRegions.isEmpty {
                            Button {
                                showProvinceList = true
                            } label: {
                                HStack {
                                    Image(systemName: "list.bullet")
                                    Text("查看 \(provinceService.visitedProvinceCount) 个已点亮省份")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color(hex: "#00d4aa"))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "#00d4aa").opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
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
            .sheet(isPresented: $showProvinceList) {
                ProvinceListView(provinceService: provinceService)
            }
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: "\(visitedCityCount)", label: "城市")
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 40)
            statItem(value: "\(provinceService.visitedProvinceCount)", label: "省份/州")
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 40)
            statItem(value: "\(countryCount)", label: "国家")
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
}

// MARK: - 省份列表视图
private struct ProvinceListView: View {
    @Environment(\.dismiss) private var dismiss
    var provinceService: ProvinceHighlightService

    // 按国家分组
    private var grouped: [(country: String, regions: [ProvinceRegion])] {
        let dict = Dictionary(grouping: provinceService.visitedRegions, by: { $0.country })
        return dict.map { (country: $0.key, regions: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.country < $1.country }
    }

    private func flagEmoji(for country: String) -> String {
        switch country.uppercased() {
        case "CN": return "🇨🇳"
        case "US": return "🇺🇸"
        case "JP": return "🇯🇵"
        case "KR": return "🇰🇷"
        case "TH": return "🇹🇭"
        case "SG": return "🇸🇬"
        case "MY": return "🇲🇾"
        case "FR": return "🇫🇷"
        case "DE": return "🇩🇪"
        case "GB": return "🇬🇧"
        case "IT": return "🇮🇹"
        case "ES": return "🇪🇸"
        case "AU": return "🇦🇺"
        case "NZ": return "🇳🇿"
        case "CA": return "🇨🇦"
        default:   return "🌍"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.country) { group in
                    Section {
                        ForEach(group.regions) { region in
                            HStack(spacing: 12) {
                                Text(flagEmoji(for: group.country))
                                    .font(.system(size: 22))
                                Text(region.name)
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "#00d4aa"))
                                    .font(.system(size: 16))
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        HStack {
                            Text(flagEmoji(for: group.country))
                            Text(countryName(for: group.country))
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("\(group.regions.count) 个")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("已点亮省份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(Color(hex: "#00d4aa"))
                }
            }
        }
    }

    private func countryName(for code: String) -> String {
        switch code.uppercased() {
        case "CN": return "中国"
        case "US": return "美国"
        case "JP": return "日本"
        case "KR": return "韩国"
        case "TH": return "泰国"
        case "SG": return "新加坡"
        case "MY": return "马来西亚"
        case "FR": return "法国"
        case "DE": return "德国"
        case "GB": return "英国"
        case "IT": return "意大利"
        case "ES": return "西班牙"
        case "AU": return "澳大利亚"
        case "NZ": return "新西兰"
        case "CA": return "加拿大"
        case "WORLD": return "海外"
        default:   return code
        }
    }
}

// MARK: - 照片光点视图（复制自 GlobeView，因其为 private）
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
