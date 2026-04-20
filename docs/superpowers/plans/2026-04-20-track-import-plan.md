# 航迹导入功能实施计划

> TravelAI · iOS 26 · Swift 6 · SwiftUI · SwiftData
> 参考「全球足迹」App 航迹导入功能（IMG_2392）

## 新增文件

| # | 路径 | 职责 |
|---|------|------|
| 1 | `Models/TrackImport.swift` | SwiftData 模型：导入记录 + 坐标点序列 |
| 2 | `Services/GPXParser.swift` | XMLParser 驱动的 GPX 解析器 |
| 3 | `Services/CSVParser.swift` | 轻量 CSV 解析器，支持多列名变体 |
| 4 | `Services/TrackImportService.swift` | @Observable 服务：分发解析、写 SwiftData、统计 |
| 5 | `Features/Home/ImportTrackView.swift` | 导入入口 Sheet |

**修改文件：** `Features/Home/FootprintView.swift`

---

## SwiftData 模型 (Models/TrackImport.swift)

```swift
import Foundation
import CoreLocation
import SwiftData

@Model final class TrackImport {
    var id: UUID
    var fileName: String
    var importedAt: Date
    var fileFormat: String        // "gpx" | "csv"
    var totalPoints: Int
    var daySpan: Int
    var startDate: Date?
    var endDate: Date?
    var isVisible: Bool
    @Relationship(deleteRule: .cascade, inverse: \TrackPoint.trackImport)
    var points: [TrackPoint]

    init(fileName: String, fileFormat: String) {
        self.id = UUID()
        self.fileName = fileName
        self.importedAt = Date()
        self.fileFormat = fileFormat
        self.totalPoints = 0
        self.daySpan = 0
        self.isVisible = true
        self.points = []
    }
}

@Model final class TrackPoint {
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var timestamp: Date?
    var sortIndex: Int
    var trackImport: TrackImport?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double, altitude: Double? = nil,
         timestamp: Date? = nil, sortIndex: Int) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.sortIndex = sortIndex
    }
}

// 临时中间结构，不存 SwiftData
struct RawTrackPoint: Sendable {
    let latitude, longitude: Double
    let altitude: Double?
    let timestamp: Date?
}
```

---

## GPX 解析器 (Services/GPXParser.swift)

```swift
import Foundation

final class GPXParser: NSObject, XMLParserDelegate {
    private var results: [RawTrackPoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentAlt: Double?
    private var currentTime: Date?
    private var currentElement = ""
    private var charBuffer = ""

    static func parse(data: Data) throws -> [RawTrackPoint] {
        let handler = GPXParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        guard parser.parse() else {
            throw GPXError.parseFailure(parser.parserError?.localizedDescription ?? "Unknown")
        }
        return handler.results
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        charBuffer = ""
        if ["trkpt", "wpt", "rtept"].contains(elementName) {
            if let latStr = attributeDict["lat"], let lonStr = attributeDict["lon"],
               let lat = Double(latStr), let lon = Double(lonStr),
               lat >= -90, lat <= 90, lon >= -180, lon <= 180 {
                currentLat = lat
                currentLon = lon
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        charBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "ele":
            currentAlt = Double(charBuffer.trimmingCharacters(in: .whitespaces))
        case "time":
            currentTime = ISO8601DateFormatter().date(from: charBuffer.trimmingCharacters(in: .whitespaces))
        case "trkpt", "wpt", "rtept":
            if let lat = currentLat, let lon = currentLon {
                results.append(RawTrackPoint(latitude: lat, longitude: lon,
                                             altitude: currentAlt, timestamp: currentTime))
            }
            currentLat = nil; currentLon = nil
            currentAlt = nil; currentTime = nil
        default: break
        }
        charBuffer = ""
    }
}

enum GPXError: LocalizedError {
    case parseFailure(String)
    var errorDescription: String? {
        if case .parseFailure(let msg) = self { return "GPX 解析失败: \(msg)" }
        return nil
    }
}
```

---

## CSV 解析器 (Services/CSVParser.swift)

```swift
import Foundation

struct CSVParser {
    static func parse(data: Data) throws -> [RawTrackPoint] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw CSVError.invalidEncoding
        }
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard !lines.isEmpty else { throw CSVError.empty }

        // 探测分隔符
        let sep: Character = detectSeparator(lines[0])

        // 列名解析
        let headers = lines[0].split(separator: sep, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        guard let latIdx = findIndex(headers: headers, candidates: ["latitude","lat","纬度","y"]),
              let lonIdx = findIndex(headers: headers, candidates: ["longitude","lon","lng","经度","x"])
        else { throw CSVError.missingCoordinateColumns }

        let timeIdx = findIndex(headers: headers, candidates: ["timestamp","time","datetime","date"])
        var results: [RawTrackPoint] = []

        for line in lines.dropFirst() {
            let cols = parseCSVLine(line, separator: sep)
            guard cols.count > max(latIdx, lonIdx),
                  let lat = Double(cols[latIdx].trimmingCharacters(in: .whitespaces)),
                  let lon = Double(cols[lonIdx].trimmingCharacters(in: .whitespaces)),
                  lat >= -90, lat <= 90, lon >= -180, lon <= 180
            else { continue }

            var ts: Date?
            if let ti = timeIdx, ti < cols.count {
                ts = parseTimestamp(cols[ti].trimmingCharacters(in: .whitespaces))
            }
            results.append(RawTrackPoint(latitude: lat, longitude: lon,
                                          altitude: nil, timestamp: ts))
        }
        return results
    }

    private static func detectSeparator(_ line: String) -> Character {
        let candidates: [(Character, Int)] = [
            (",", line.filter { $0 == "," }.count),
            ("\t", line.filter { $0 == "\t" }.count),
            (";", line.filter { $0 == ";" }.count)
        ]
        return candidates.max(by: { $0.1 < $1.1 })?.0 ?? ","
    }

    private static func findIndex(headers: [String], candidates: [String]) -> Int? {
        for c in candidates { if let i = headers.firstIndex(of: c) { return i } }
        return nil
    }

    private static func parseCSVLine(_ line: String, separator: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle() }
            else if ch == separator && !inQuotes { result.append(current); current = "" }
            else { current.append(ch) }
        }
        result.append(current)
        return result
    }

    private static func parseTimestamp(_ s: String) -> Date? {
        let formatters: [DateFormatter] = [
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm:ss"; return f }()
        ]
        if let d = ISO8601DateFormatter().date(from: s) { return d }
        if let epoch = Double(s) { return Date(timeIntervalSince1970: epoch > 1e10 ? epoch/1000 : epoch) }
        for fmt in formatters { if let d = fmt.date(from: s) { return d } }
        return nil
    }
}

enum CSVError: LocalizedError {
    case invalidEncoding, empty, missingCoordinateColumns
    var errorDescription: String? {
        switch self {
        case .invalidEncoding: return "文件编码不是 UTF-8"
        case .empty: return "文件为空"
        case .missingCoordinateColumns: return "找不到经纬度列（需要 latitude/longitude 列名）"
        }
    }
}
```

---

## TrackImportService (Services/TrackImportService.swift)

```swift
import Foundation
import SwiftData

enum TrackImportState: Equatable {
    case idle
    case parsing
    case saving(progress: Double)
    case success(Int)  // 成功导入点数
    case failure(String)
}

@Observable
@MainActor
final class TrackImportService {
    var state: TrackImportState = .idle
    var allImports: [TrackImport] = []

    var totalTrackPoints: Int { allImports.reduce(0) { $0 + $1.totalPoints } }

    func importFile(url: URL, context: ModelContext) async {
        state = .parsing

        do {
            // 访问沙箱外文件
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()

            let rawPoints: [RawTrackPoint] = try await Task.detached(priority: .userInitiated) {
                switch ext {
                case "gpx": return try GPXParser.parse(data: data)
                case "csv": return try CSVParser.parse(data: data)
                default:
                    // 未知格式：先尝试 GPX，再尝试 CSV
                    if let r = try? GPXParser.parse(data: data), !r.isEmpty { return r }
                    return try CSVParser.parse(data: data)
                }
            }.value

            guard !rawPoints.isEmpty else {
                state = .failure("文件中没有有效坐标点")
                return
            }

            // 创建 TrackImport 记录
            let imp = TrackImport(fileName: url.lastPathComponent, fileFormat: ext)
            context.insert(imp)

            // 分批写入（每批 500）
            let batchSize = 500
            for (i, raw) in rawPoints.enumerated() {
                let pt = TrackPoint(latitude: raw.latitude, longitude: raw.longitude,
                                    altitude: raw.altitude, timestamp: raw.timestamp,
                                    sortIndex: i)
                pt.trackImport = imp
                context.insert(pt)

                if i % batchSize == 0 {
                    state = .saving(progress: Double(i) / Double(rawPoints.count))
                    try context.save()
                }
            }

            // 计算统计
            imp.totalPoints = rawPoints.count
            let days = Set(rawPoints.compactMap { $0.timestamp }.map {
                Calendar.current.startOfDay(for: $0)
            })
            imp.daySpan = days.count
            if let first = rawPoints.compactMap({ $0.timestamp }).min() { imp.startDate = first }
            if let last  = rawPoints.compactMap({ $0.timestamp }).max() { imp.endDate   = last  }

            try context.save()
            loadAll(context: context)
            state = .success(rawPoints.count)

        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func delete(_ imp: TrackImport, context: ModelContext) {
        context.delete(imp)
        try? context.save()
        loadAll(context: context)
    }

    func toggleVisibility(_ imp: TrackImport, context: ModelContext) {
        imp.isVisible.toggle()
        try? context.save()
    }

    func loadAll(context: ModelContext) {
        let descriptor = FetchDescriptor<TrackImport>(sortBy: [SortDescriptor(\.importedAt, order: .reverse)])
        allImports = (try? context.fetch(descriptor)) ?? []
    }
}
```

---

## 实施顺序

```
Task 1  Models/TrackImport.swift          ← 所有依赖的基础
Task 2  Services/GPXParser.swift          ← 可并行 Task 3
Task 3  Services/CSVParser.swift          ← 可并行 Task 2
Task 4  Services/TrackImportService.swift ← 依赖 1、2、3
Task 5  Features/Home/ImportTrackView.swift ← 依赖 4
Task 6  Features/Home/FootprintView.swift 修改 ← 依赖 4、5
Task 7  HomeView.swift 修改              ← 依赖 4、6
Task 8  TravelAIApp.swift Schema 注册    ← 依赖 1
Task 9  集成测试
```
