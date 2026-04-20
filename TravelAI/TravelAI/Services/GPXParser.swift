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
