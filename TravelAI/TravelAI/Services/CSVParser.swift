import Foundation

struct CSVParser {
    static func parse(data: Data) throws -> [RawTrackPoint] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw CSVError.invalidEncoding
        }
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard !lines.isEmpty else { throw CSVError.empty }

        // Detect separator
        let sep: Character = detectSeparator(lines[0])

        // Parse column names
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
