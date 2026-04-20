# 航迹导入功能完整实施计划

> TravelAI · iOS 26 · Swift 6 · SwiftUI · SwiftData · @Observable
> 编写日期：2026-04-20

---

## 1. 新增文件列表

| # | 路径 | 职责（一句话） |
|---|------|----------------|
| 1 | `Models/TrackImport.swift` | SwiftData 模型：一次导入记录（含元数据） + 坐标点序列 |
| 2 | `Services/GPXParser.swift` | XMLParser 驱动的 GPX 文件解析器，输出 `[RawTrackPoint]` |
| 3 | `Services/CSVParser.swift` | 轻量 CSV 解析器，支持多列名变体，输出 `[RawTrackPoint]` |
| 4 | `Services/TrackImportService.swift` | `@Observable` 服务：文件分发、解析、写入 SwiftData、统计计算 |
| 5 | `Features/Home/ImportTrackView.swift` | SwiftUI 导入入口 Sheet：格式说明 + `.fileImporter` + 进度/结果 |
| 6 | `Features/Home/TrackOverlayView.swift` | 在地图上渲染已导入轨迹的 `MapPolyline` + 密集小点 |

**修改文件：**

| 路径 | 改动说明 |
|------|----------|
| `Features/Home/FootprintView.swift` | 注入 `TrackImportService`；地图叠加轨迹；底部「+」浮动按钮；顶部统计扩展 |

---

## 2. SwiftData 模型设计

### `Models/TrackImport.swift`

```swift
// Models/TrackImport.swift
import SwiftData
import Foundation
import CoreLocation

// MARK: - 一次导入记录
@Model
final class TrackImport {
    var id: UUID
    var fileName: String          // 原始文件名，如 "hike_2025.gpx"
    var importedAt: Date          // 导入时间
    var fileFormat: String        // "gpx" | "csv"
    var totalPoints: Int          // 坐标点总数（冗余，快速读取）
    var daySpan: Int              // 跨越天数（首尾时间差）
    var startDate: Date?          // 最早时间戳（可为 nil，如无时间信息）
    var endDate: Date?            // 最晚时间戳
    var isVisible: Bool           // 地图是否显示

    /// 坐标点集合（cascade 删除）
    @Relationship(deleteRule: .cascade, inverse: \TrackPoint.trackImport)
    var points: [TrackPoint]

    init(
        fileName: String,
        fileFormat: String,
        totalPoints: Int = 0,
        daySpan: Int = 0,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isVisible: Bool = true
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.importedAt = Date()
        self.fileFormat = fileFormat
        self.totalPoints = totalPoints
        self.daySpan = daySpan
        self.startDate = startDate
        self.endDate = endDate
        self.isVisible = isVisible
        self.points = []
    }
}

// MARK: - 单个坐标点
@Model
final class TrackPoint {
    var latitude: Double
    var longitude: Double
    var altitude: Double?         // 海拔（米），可选
    var timestamp: Date?          // 时间戳，可选
    var sortIndex: Int            // 保序索引

    /// 反向关联，SwiftData 要求手动声明
    var trackImport: TrackImport?

    init(latitude: Double, longitude: Double,
         altitude: Double? = nil, timestamp: Date? = nil,
         sortIndex: Int = 0) {
        self.latitude  = latitude
        self.longitude = longitude
        self.altitude  = altitude
        self.timestamp = timestamp
        self.sortIndex = sortIndex
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 临时中间结构（解析器输出，不存入 SwiftData）
struct RawTrackPoint {
    let latitude:  Double
    let longitude: Double
    let altitude:  Double?
    let timestamp: Date?
}
```

---

## 3. GPX 解析器

### `Services/GPXParser.swift`

```swift
// Services/GPXParser.swift
import Foundation

// MARK: - GPXParser（基于 XMLParser 的 SAX 解析器）
final class GPXParser: NSObject {

    // MARK: - Public API
    /// 同步解析（建议在 Task.detached 内调用）
    static func parse(data: Data) throws -> [RawTrackPoint] {
        let parser = GPXParser()
        return try parser._parse(data: data)
    }

    // MARK: - Private State
    private var points: [RawTrackPoint] = []
    private var currentLat:  Double?
    private var currentLon:  Double?
    private var currentAlt:  Double?
    private var currentTime: Date?
    private var inTrkpt   = false
    private var inEle     = false
    private var inTime    = false
    private var currentCharacters = ""

    /// ISO 8601 解析器（线程局部，避免锁竞争）
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private var parseError: Error?

    // MARK: - 解析入口
    private func _parse(data: Data) throws -> [RawTrackPoint] {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()
        if let err = parseError { throw err }
        return points
    }
}

// MARK: - XMLParserDelegate
extension GPXParser: XMLParserDelegate {

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        let tag = elementName.lowercased()

        // <trkpt> 或 <wpt>（路点也纳入）
        if tag == "trkpt" || tag == "wpt" || tag == "rtept" {
            inTrkpt = true
            currentLat  = Double(attributeDict["lat"] ?? "")
            currentLon  = Double(attributeDict["lon"] ?? "")
            currentAlt  = nil
            currentTime = nil
        } else if inTrkpt {
            switch tag {
            case "ele":  inEle  = true
            case "time": inTime = true
            default: break
            }
            currentCharacters = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inTrkpt else { return }
        currentCharacters += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let tag = elementName.lowercased()

        if inTrkpt {
            switch tag {
            case "ele":
                currentAlt = Double(currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines))
                inEle = false

            case "time":
                let raw = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
                currentTime = isoFormatter.date(from: raw)
                    ?? isoFormatterNoFrac.date(from: raw)
                inTime = false

            case "trkpt", "wpt", "rtept":
                if let lat = currentLat, let lon = currentLon,
                   lat >= -90 && lat <= 90,
                   lon >= -180 && lon <= 180 {
                    points.append(RawTrackPoint(
                        latitude:  lat,
                        longitude: lon,
                        altitude:  currentAlt,
                        timestamp: currentTime
                    ))
                }
                inTrkpt = false

            default: break
            }
            currentCharacters = ""
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}
```

---

## 4. CSV 解析器

### `Services/CSVParser.swift`

```swift
// Services/CSVParser.swift
import Foundation

// MARK: - CSVParser
/// 支持格式：
///   标准：latitude,longitude,timestamp
///   变体：lat,lng,time  |  lat,lon,datetime  |  Latitude,Longitude,Time
///   无时间戳列（仅坐标）：latitude,longitude
///   逗号/制表符/分号均可
enum CSVParser {

    // MARK: - Errors
    enum ParseError: LocalizedError {
        case emptyFile
        case noHeaderRow
        case missingCoordinateColumns
        case noValidRows

        var errorDescription: String? {
            switch self {
            case .emptyFile:                return "CSV 文件为空"
            case .noHeaderRow:              return "未找到表头行"
            case .missingCoordinateColumns: return "CSV 缺少 latitude/longitude 列"
            case .noValidRows:              return "CSV 中没有有效坐标行"
            }
        }
    }

    // MARK: - Public API
    static func parse(data: Data) throws -> [RawTrackPoint] {
        guard let content = String(data: data, encoding: .utf8)
                            ?? String(data: data, encoding: .isoLatin1) else {
            throw ParseError.emptyFile
        }
        return try parseString(content)
    }

    // MARK: - 内部解析
    private static func parseString(_ content: String) throws -> [RawTrackPoint] {
        // 分行，过滤空行
        var lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { throw ParseError.emptyFile }

        // 自动检测分隔符：逗号/制表符/分号
        let delimiter: Character = detectDelimiter(lines[0])

        // 解析表头
        let header = lines.removeFirst().split(separator: delimiter, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard !header.isEmpty else { throw ParseError.noHeaderRow }

        // 定位列索引
        let latIdx  = columnIndex(in: header, candidates: ["latitude",  "lat",  "纬度", "y"])
        let lonIdx  = columnIndex(in: header, candidates: ["longitude", "lon",  "lng", "经度", "x"])
        let timeIdx = columnIndex(in: header, candidates: ["timestamp", "time", "datetime", "date", "时间"])
        let altIdx  = columnIndex(in: header, candidates: ["altitude",  "alt",  "elevation", "ele", "高度"])

        guard let latCol = latIdx, let lonCol = lonIdx else {
            throw ParseError.missingCoordinateColumns
        }

        let dateParser = makeDateParser()
        var points: [RawTrackPoint] = []
        points.reserveCapacity(lines.count)

        for line in lines {
            // 跳过注释行
            if line.hasPrefix("#") || line.hasPrefix("//") { continue }

            let cols = split(line: line, delimiter: delimiter)
            guard cols.count > max(latCol, lonCol) else { continue }

            guard let lat = Double(cols[latCol].trimmingCharacters(in: .whitespacesAndNewlines)),
                  let lon = Double(cols[lonCol].trimmingCharacters(in: .whitespacesAndNewlines)),
                  lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { continue }

            var ts: Date? = nil
            if let tc = timeIdx, tc < cols.count {
                let raw = cols[tc].trimmingCharacters(in: .whitespacesAndNewlines)
                ts = dateParser(raw)
            }

            var alt: Double? = nil
            if let ac = altIdx, ac < cols.count {
                alt = Double(cols[ac].trimmingCharacters(in: .whitespacesAndNewlines))
            }

            points.append(RawTrackPoint(latitude: lat, longitude: lon,
                                        altitude: alt, timestamp: ts))
        }

        guard !points.isEmpty else { throw ParseError.noValidRows }
        return points
    }

    // MARK: - Helpers

    /// 自动探测分隔符（取第一行中出现最多的常见分隔符）
    private static func detectDelimiter(_ line: String) -> Character {
        let candidates: [Character] = [",", "\t", ";", "|"]
        return candidates.max(by: { line.filter { $0 == $0 }.count < line.filter { $0 == $1 }.count })
            ?? ","
    }

    /// 忽略大小写的列索引定位
    private static func columnIndex(in header: [String], candidates: [String]) -> Int? {
        for candidate in candidates {
            if let idx = header.firstIndex(of: candidate) { return idx }
        }
        return nil
    }

    /// 支持引号内含分隔符的 CSV 分割
    private static func split(line: String, delimiter: Character) -> [String] {
        var cols: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == delimiter && !inQuotes {
                cols.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        cols.append(current)
        return cols
    }

    /// 构造一个支持多种格式的日期解析闭包（避免重复创建 Formatter）
    private static func makeDateParser() -> (String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]

        // Unix 毫秒 / 秒
        let unixMs: (String) -> Date? = { s in
            guard let v = Double(s) else { return nil }
            // 若超过 1e10 认为是毫秒
            return v > 1e10 ? Date(timeIntervalSince1970: v / 1000) : Date(timeIntervalSince1970: v)
        }

        let fmtList: [DateFormatter] = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "MM/dd/yyyy HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy"
        ].map {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = $0
            return f
        }

        return { raw in
            if let d = iso.date(from: raw)       { return d }
            if let d = isoNoFrac.date(from: raw) { return d }
            if let d = unixMs(raw)               { return d }
            for fmt in fmtList {
                if let d = fmt.date(from: raw)   { return d }
            }
            return nil
        }
    }
}
```

---

## 5. TrackImportService

### `Services/TrackImportService.swift`

```swift
// Services/TrackImportService.swift
import Foundation
import SwiftData
import SwiftUI

// MARK: - 导入状态
enum TrackImportState: Equatable {
    case idle
    case parsing                    // 正在解析文件
    case saving(progress: Double)   // 正在写入 SwiftData（0~1）
    case success(summary: ImportSummary)
    case failure(message: String)
}

struct ImportSummary: Equatable {
    let fileName: String
    let totalPoints: Int
    let daySpan: Int
    let format: String
}

// MARK: - TrackImportService
@Observable
@MainActor
final class TrackImportService {

    // MARK: - 可观测属性
    var state: TrackImportState = .idle
    var allImports: [TrackImport] = []   // 全部已导入记录（从 SwiftData 加载）

    // MARK: - 统计（跨所有导入）
    var totalTrackPoints: Int {
        allImports.reduce(0) { $0 + $1.totalPoints }
    }

    var uniqueDaySpan: Int {
        // 收集所有有时间戳的点的日期集合
        let calendar = Calendar.current
        var days = Set<DateComponents>()
        for imp in allImports where imp.isVisible {
            for pt in imp.points {
                guard let ts = pt.timestamp else { continue }
                let comps = calendar.dateComponents([.year, .month, .day], from: ts)
                days.insert(comps)
            }
        }
        return days.count
    }

    // MARK: - 导入入口
    /// 由 UI 层调用，传入用户选择的文件 URL（可为 security-scoped）
    func importFile(url: URL, context: ModelContext) async {
        state = .parsing

        do {
            // 1. 读取文件数据（security-scoped 资源）
            let data = try readSecureFile(url: url)
            let fileName = url.lastPathComponent
            let ext = url.pathExtension.lowercased()

            // 2. 根据扩展名分发解析器（后台线程）
            let rawPoints: [RawTrackPoint] = try await Task.detached(priority: .userInitiated) {
                switch ext {
                case "gpx":
                    return try GPXParser.parse(data: data)
                case "csv", "txt":
                    return try CSVParser.parse(data: data)
                default:
                    // 尝试 GPX 再试 CSV
                    if let pts = try? GPXParser.parse(data: data), !pts.isEmpty { return pts }
                    return try CSVParser.parse(data: data)
                }
            }.value

            guard !rawPoints.isEmpty else {
                state = .failure(message: "未能从文件中解析出有效坐标点")
                return
            }

            // 3. 统计
            let (daySpan, startDate, endDate) = computeTimeStats(rawPoints)
            let summary = ImportSummary(
                fileName: fileName,
                totalPoints: rawPoints.count,
                daySpan: daySpan,
                format: ext
            )

            // 4. 写入 SwiftData（分批，避免主线程卡顿）
            state = .saving(progress: 0)
            try await saveToSwiftData(
                rawPoints: rawPoints,
                fileName: fileName,
                fileFormat: ext,
                daySpan: daySpan,
                startDate: startDate,
                endDate: endDate,
                context: context
            )

            // 5. 刷新本地缓存
            loadAll(context: context)
            state = .success(summary: summary)

        } catch {
            state = .failure(message: error.localizedDescription)
        }
    }

    // MARK: - 删除导入记录
    func delete(_ trackImport: TrackImport, context: ModelContext) {
        context.delete(trackImport)
        try? context.save()
        loadAll(context: context)
    }

    // MARK: - 切换可见性
    func toggleVisibility(_ trackImport: TrackImport, context: ModelContext) {
        trackImport.isVisible.toggle()
        try? context.save()
    }

    // MARK: - 重置为 idle
    func resetState() {
        state = .idle
    }

    // MARK: - 从 SwiftData 加载所有记录
    func loadAll(context: ModelContext) {
        let descriptor = FetchDescriptor<TrackImport>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        allImports = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Private: 读取 Security-Scoped 文件
    private func readSecureFile(url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }

    // MARK: - Private: 时间统计
    private func computeTimeStats(
        _ points: [RawTrackPoint]
    ) -> (daySpan: Int, start: Date?, end: Date?) {
        let timestamps = points.compactMap(\.timestamp).sorted()
        guard let first = timestamps.first, let last = timestamps.last else {
            return (0, nil, nil)
        }
        let calendar = Calendar.current
        let daySpan = calendar.dateComponents([.day], from: first, to: last).day.map { $0 + 1 } ?? 1
        return (daySpan, first, last)
    }

    // MARK: - Private: 写入 SwiftData（分批 500 条上报进度）
    private func saveToSwiftData(
        rawPoints: [RawTrackPoint],
        fileName: String,
        fileFormat: String,
        daySpan: Int,
        startDate: Date?,
        endDate: Date?,
        context: ModelContext
    ) async throws {
        let batchSize = 500
        let total = rawPoints.count

        // 创建主记录
        let trackImport = TrackImport(
            fileName: fileName,
            fileFormat: fileFormat,
            totalPoints: total,
            daySpan: daySpan,
            startDate: startDate,
            endDate: endDate
        )
        context.insert(trackImport)

        // 分批插入坐标点
        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, total)
            let batch = rawPoints[batchStart..<batchEnd]

            for (i, raw) in batch.enumerated() {
                let pt = TrackPoint(
                    latitude:  raw.latitude,
                    longitude: raw.longitude,
                    altitude:  raw.altitude,
                    timestamp: raw.timestamp,
                    sortIndex: batchStart + i
                )
                pt.trackImport = trackImport
                context.insert(pt)
            }

            // 更新进度（回主线程）
            let progress = Double(batchEnd) / Double(total)
            await MainActor.run {
                self.state = .saving(progress: progress)
            }

            // 每批 yield 一次，避免阻塞
            await Task.yield()
        }

        try context.save()
    }
}
```

---

## 6. 导入 UI

### `Features/Home/ImportTrackView.swift`

```swift
// Features/Home/ImportTrackView.swift
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ImportTrackView
struct ImportTrackView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    var trackService: TrackImportService

    @State private var showFilePicker = false
    @State private var pickerError: String? = nil

    // 支持的 UTType
    private let supportedTypes: [UTType] = [
        UTType(filenameExtension: "gpx") ?? .data,
        .commaSeparatedText,
        .tabSeparatedText,
        .plainText
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBGGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // 顶部图标 + 标题
                        headerSection

                        // 格式说明卡片
                        formatInfoCard

                        // 已导入记录列表
                        if !trackService.allImports.isEmpty {
                            importedListSection
                        }

                        // 底部 CTA
                        importButton

                        // 错误提示
                        if let err = pickerError {
                            Text(err)
                                .font(AppFont.body(13))
                                .foregroundColor(AppTheme.red)
                                .padding(.horizontal, AppTheme.padding)
                        }

                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, AppTheme.padding)
                    .padding(.top, AppTheme.Spacing.md)
                }
            }
            .navigationTitle("导入航迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
            // 文件选择器
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                handlePickerResult(result)
            }
            // 进度/结果遮罩
            .overlay {
                if case .parsing = trackService.state {
                    progressOverlay(message: "正在解析文件…", progress: nil)
                } else if case .saving(let p) = trackService.state {
                    progressOverlay(message: "正在写入数据库…", progress: p)
                } else if case .success(let summary) = trackService.state {
                    successOverlay(summary: summary)
                } else if case .failure(let msg) = trackService.state {
                    failureOverlay(message: msg)
                }
            }
            .onAppear {
                trackService.loadAll(context: modelContext)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentBG)
                    .frame(width: 72, height: 72)
                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(AppTheme.accentGradient)
            }
            Text("导入 GPS 航迹")
                .font(AppFont.heading(22))
                .foregroundColor(AppTheme.textPrimary)
            Text("将 GPX / CSV 格式的轨迹文件导入地图，\n可视化你的每一段旅程。")
                .font(AppFont.body(14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Spacing.sm)
    }

    // MARK: - 格式说明卡片
    private var formatInfoCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label("支持的格式", systemImage: "doc.text")
                .font(AppFont.headingSmall(15))
                .foregroundColor(AppTheme.textPrimary)

            Divider().background(AppTheme.border)

            formatRow(
                icon: "globe",
                title: "GPX 文件（.gpx）",
                desc: "标准 GPS 轨迹格式，支持 <trkpt>、<wpt>、<rtept>，含时间戳和海拔"
            )

            Divider().background(AppTheme.borderSubtle)

            formatRow(
                icon: "tablecells",
                title: "CSV 表格（.csv / .txt）",
                desc: "需包含 latitude、longitude 列，可选 timestamp / altitude"
            )

            Divider().background(AppTheme.borderSubtle)

            // CSV 示例
            VStack(alignment: .leading, spacing: 4) {
                Text("CSV 示例：")
                    .font(AppFont.caption(11, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
                Text("latitude,longitude,timestamp\n31.2304,121.4737,2025-06-01T09:00:00Z")
                    .font(AppFont.mono(11))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(8)
                    .background(AppTheme.sectionBG)
                    .cornerRadius(AppTheme.cardRadiusSmall)
            }
        }
        .padding(AppTheme.padding)
        .background(AppTheme.cardBG)
        .cornerRadius(AppTheme.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius)
            .stroke(AppTheme.border, lineWidth: 1))
        .appShadow(AppTheme.softLift())
    }

    private func formatRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.accent)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(desc)
                    .font(AppFont.body(12))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - 已导入列表
    private var importedListSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("已导入的航迹")
                .font(AppFont.headingSmall(15))
                .foregroundColor(AppTheme.textPrimary)

            ForEach(trackService.allImports) { imp in
                ImportedTrackRow(
                    trackImport: imp,
                    onToggle: {
                        trackService.toggleVisibility(imp, context: modelContext)
                    },
                    onDelete: {
                        trackService.delete(imp, context: modelContext)
                    }
                )
            }
        }
    }

    // MARK: - 导入按钮
    private var importButton: some View {
        Button {
            pickerError = nil
            showFilePicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                Text("选择文件")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.accentGradient)
            .cornerRadius(AppTheme.cardRadius)
            .appShadow(AppTheme.accentGlow())
        }
        .buttonStyle(AccentButtonStyle())
    }

    // MARK: - 处理文件选择结果
    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await trackService.importFile(url: url, context: modelContext)
            }
        case .failure(let error):
            pickerError = "文件访问失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 进度遮罩
    private func progressOverlay(message: String, progress: Double?) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: AppTheme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(AppTheme.accent)
                Text(message)
                    .font(AppFont.body(15, weight: .medium))
                    .foregroundColor(.white)
                if let p = progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.2)).frame(height: 6)
                            Capsule()
                                .fill(AppTheme.accentGradient)
                                .frame(width: geo.size.width * p, height: 6)
                                .animation(.easeInOut(duration: 0.3), value: p)
                        }
                    }
                    .frame(width: 200, height: 6)
                    Text("\(Int(p * 100))%")
                        .font(AppFont.mono(12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(AppTheme.paddingLarge)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardRadiusLarge))
        }
    }

    // MARK: - 成功遮罩
    private func successOverlay(summary: ImportSummary) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
                Text("导入成功！")
                    .font(AppFont.heading(20))
                    .foregroundColor(.white)
                VStack(spacing: 6) {
                    Text(summary.fileName)
                        .font(AppFont.body(13))
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(summary.totalPoints) 个轨迹点")
                        .font(AppFont.body(16, weight: .semibold))
                        .foregroundColor(.white)
                    if summary.daySpan > 0 {
                        Text("跨越 \(summary.daySpan) 天")
                            .font(AppFont.body(13))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                Button("完成") {
                    trackService.resetState()
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 36).padding(.vertical, 12)
                .background(AppTheme.accentGradient)
                .cornerRadius(22)
            }
            .padding(AppTheme.paddingLarge)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardRadiusLarge))
        }
    }

    // MARK: - 失败遮罩
    private func failureOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(AppTheme.red)
                Text("导入失败")
                    .font(AppFont.heading(20))
                    .foregroundColor(.white)
                Text(message)
                    .font(AppFont.body(13))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button("重试") { trackService.resetState() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 36).padding(.vertical, 12)
                    .background(AppTheme.red)
                    .cornerRadius(22)
            }
            .padding(AppTheme.paddingLarge)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardRadiusLarge))
        }
    }
}

// MARK: - 单条已导入记录行
private struct ImportedTrackRow: View {
    let trackImport: TrackImport
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 格式图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(trackImport.fileFormat == "gpx" ? AppTheme.tealBG : AppTheme.accentBG)
                    .frame(width: 36, height: 36)
                Image(systemName: trackImport.fileFormat == "gpx" ? "globe" : "tablecells")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(trackImport.fileFormat == "gpx" ? AppTheme.teal : AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(trackImport.fileName)
                    .font(AppFont.body(14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(trackImport.totalPoints) 点")
                        .font(AppFont.caption(11))
                        .foregroundColor(AppTheme.textTertiary)
                    if trackImport.daySpan > 0 {
                        Text("·")
                            .foregroundColor(AppTheme.textTertiary)
                        Text("\(trackImport.daySpan) 天")
                            .font(AppFont.caption(11))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    Text("·")
                        .foregroundColor(AppTheme.textTertiary)
                    Text(trackImport.importedAt, style: .date)
                        .font(AppFont.caption(11))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }

            Spacer()

            // 可见性开关
            Toggle("", isOn: Binding(
                get: { trackImport.isVisible },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .scaleEffect(0.8)
            .tint(AppTheme.accent)

            // 删除按钮
            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.red)
            }
        }
        .padding(AppTheme.paddingSmall)
        .background(AppTheme.cardBG)
        .cornerRadius(AppTheme.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius)
            .stroke(AppTheme.borderSubtle, lineWidth: 1))
    }
}
```

---

## 7. FootprintView 修改说明

### 7.1 需要修改的部分（完整 diff 风格说明）

#### 步骤 A：在 `HomeView` 注入 `TrackImportService`

在 `HomeView.swift` 的 `@State` 区域添加：

```swift
@State private var trackImportService = TrackImportService()
@State private var showImportTrack = false
```

在 `.onAppear` 块中添加初始加载：

```swift
trackService.loadAll(context: modelContext)
```

在 `showFootprint` 的 `.sheet` 后面添加：

```swift
.sheet(isPresented: $showImportTrack) {
    ImportTrackView(trackService: trackImportService)
}
```

将 `FootprintView` 的调用改为传入 `trackImportService`：

```swift
.sheet(isPresented: $showFootprint) {
    FootprintView(
        provinceService: provinceService,
        photoService: photoService,
        trackService: trackImportService   // ← 新增
    )
}
```

---

#### 步骤 B：修改 `FootprintView.swift` — 完整新版本

```swift
// Features/Home/FootprintView.swift
import SwiftUI
import MapKit
import SwiftData

struct FootprintView: View {
    @Environment(\.dismiss) private var dismiss
    var provinceService: ProvinceHighlightService
    var photoService: PhotoMemoryService
    var trackService: TrackImportService          // ← 新增注入

    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var showProvinceList = false
    @State private var showImportTrack  = false   // ← 新增
    @State private var importButtonScale: CGFloat = 1.0  // ← 按钮弹跳动画

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
                // ──────────────────── 地图背景（全屏）────────────────────
                Map {
                    // 省份高亮（底层）
                    ForEach(provinceService.visitedRegions) { region in
                        ForEach(Array(region.polygons.enumerated()), id: \.offset) { _, poly in
                            MapPolygon(coordinates: poly)
                                .foregroundStyle(Color(hex: "#00d4aa").opacity(0.32))
                                .stroke(Color(hex: "#00d4aa").opacity(0.8), lineWidth: 1.5)
                        }
                    }

                    // ── 航迹轨迹（新增）──
                    ForEach(trackService.allImports.filter(\.isVisible)) { imp in
                        let coords = imp.points
                            .sorted { $0.sortIndex < $1.sortIndex }
                            .map(\.coordinate)
                        if coords.count >= 2 {
                            // 轨迹线
                            MapPolyline(coordinates: coords)
                                .stroke(.cyan.opacity(0.75), lineWidth: 2.5)
                        }
                        // 密集小点（每 N 个取一个，避免性能问题）
                        let stride = max(1, coords.count / 300)
                        ForEach(Array(coords.enumerated().filter { $0.offset % stride == 0 }),
                                id: \.offset) { _, coord in
                            Annotation("", coordinate: coord, anchor: .center) {
                                Circle()
                                    .fill(Color.cyan.opacity(0.85))
                                    .frame(width: 4, height: 4)
                                    .shadow(color: .cyan, radius: 2)
                            }
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

                // ──────────────────── 覆盖层 ────────────────────
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 统计卡片（扩展航迹统计）
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
                    .padding(.bottom, 100) // 底部留出「+」按钮空间
                }

                // ──────────────────── 「+」浮动按钮（新增）────────────────────
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(AppTheme.animBounce) {
                                importButtonScale = 0.88
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                withAnimation(AppTheme.animBounce) { importButtonScale = 1.0 }
                                showImportTrack = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accentGradient)
                                    .frame(width: 56, height: 56)
                                    .appShadow(AppTheme.accentGlow())
                                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(importButtonScale)
                        }
                        .buttonStyle(.plain)
                        // 角标：已导入数量
                        .overlay(alignment: .topTrailing) {
                            if !trackService.allImports.isEmpty {
                                Text("\(trackService.allImports.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(AppTheme.red)
                                    .clipShape(Capsule())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 36)
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
            // ← 新增导入 Sheet
            .sheet(isPresented: $showImportTrack) {
                ImportTrackView(trackService: trackService)
            }
        }
    }

    // MARK: - 统计卡片（扩展了航迹统计）
    private var statsCard: some View {
        VStack(spacing: 0) {
            // 原有三项统计
            HStack(spacing: 0) {
                statItem(value: "\(visitedCityCount)", label: "城市")
                divider
                statItem(value: "\(provinceService.visitedProvinceCount)", label: "省份/州")
                divider
                statItem(value: "\(countryCount)", label: "国家")
            }
            .padding(.vertical, 16)

            // 航迹统计（有数据时显示）
            if trackService.totalTrackPoints > 0 {
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.horizontal, 16)

                HStack(spacing: 0) {
                    statItem(
                        value: formatTrackPoints(trackService.totalTrackPoints),
                        label: "轨迹点",
                        color: .cyan
                    )
                    divider
                    statItem(
                        value: "\(trackService.uniqueDaySpan)",
                        label: "天",
                        color: .cyan
                    )
                    divider
                    statItem(
                        value: "\(trackService.allImports.count)",
                        label: "条轨迹",
                        color: .cyan
                    )
                }
                .padding(.vertical, 12)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 1, height: 40)
    }

    private func statItem(value: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    /// 将大数字格式化为 "12.3K" / "1.2M"
    private func formatTrackPoints(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
```

> **注意：** `ProvinceListView`、`PhotoDotView` 等 private 子视图保持不变，此处略去以减少篇幅。

---

## 8. 实施顺序（按依赖关系）

```
Task 1  ─ Models/TrackImport.swift
          创建 TrackImport、TrackPoint @Model，定义 RawTrackPoint 中间结构
          ⚙️ 前置：无；后置：所有 Service 依赖

Task 2  ─ Services/GPXParser.swift
          实现 GPXParser，单元测试可用 Bundle 内置示例 GPX 文件
          ⚙️ 前置：RawTrackPoint；后置：TrackImportService

Task 3  ─ Services/CSVParser.swift
          实现 CSVParser，覆盖多列名变体 + 时间戳格式
          ⚙️ 前置：RawTrackPoint；后置：TrackImportService

Task 4  ─ Services/TrackImportService.swift
          组装 importFile / saveToSwiftData / 统计逻辑
          ⚙️ 前置：Task 1、2、3；后置：UI 层

Task 5  ─ Features/Home/ImportTrackView.swift
          构建导入 Sheet UI（fileImporter + 进度 + 结果遮罩 + 已导入列表）
          ⚙️ 前置：Task 4；后置：FootprintView 集成

Task 6  ─ Features/Home/FootprintView.swift（修改）
          a) 接收 trackService 参数
          b) 地图内添加 MapPolyline + 密集点
          c) 底部「+」浮动按钮 → showImportTrack
          d) 统计卡片增加第二行航迹统计
          ⚙️ 前置：Task 4、5

Task 7  ─ HomeView.swift（修改）
          a) 添加 @State trackImportService
          b) 传入 FootprintView
          c) .onAppear 调用 loadAll
          ⚙️ 前置：Task 4、6

Task 8  ─ Xcode Project Settings
          在 Info.plist 确认无需特殊 Key（fileImporter 不需要额外权限）
          在 SwiftData ModelContainer 的 schema 中注册 TrackImport、TrackPoint
          ⚙️ 前置：Task 1

Task 9  ─ 集成测试
          a) 用真实 GPX 文件（如手机导出的运动轨迹）验证解析正确性
          b) 验证 SwiftData 大文件（>10000 点）插入性能
          c) 验证地图 MapPolyline 渲染流畅性（sampling 策略）
          ⚙️ 前置：所有 Task
```

---

## 附录：SwiftData Schema 注册

在 App 入口 (`TravelAIApp.swift`) 的 `ModelContainer` schema 中添加新模型：

```swift
let schema = Schema([
    Trip.self,
    TripDay.self,
    TripEvent.self,
    ChecklistItem.self,
    CultureData.self,
    Message.self,
    SOSContact.self,
    TrackImport.self,   // ← 新增
    TrackPoint.self     // ← 新增
])
```

---

## 附录：性能注意事项

| 场景 | 问题 | 方案 |
|------|------|------|
| GPX 文件 > 50,000 点 | 主线程卡顿 | `Task.detached` 解析 + 分批 500 条写入 |
| MapPolyline 点过密 | 渲染帧率下降 | 地图渲染时每 N 点取 1（N = max(1, count/300)） |
| TrackPoint 大量查询 | 冷启动慢 | TrackImport 存 totalPoints 冗余字段，避免 COUNT |
| 多条轨迹叠加 | 地图混乱 | isVisible 开关 + 独立颜色区分（可扩展） |

---

*End of document.*
