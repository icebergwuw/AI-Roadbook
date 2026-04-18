import Foundation
import SwiftData

// 纯 Swift 结构体，不依赖 SwiftData，安全跨线程传递
struct ParsedTrip {
    struct Day {
        var date: Date
        var title: String
        var sortIndex: Int
        var events: [Event]
    }
    struct Event {
        var time: String
        var title: String
        var description: String
        var locationName: String
        var latitude: Double?
        var longitude: Double?
        var eventType: String
        var sortIndex: Int
    }
    struct ChecklistEntry {
        var title: String
        var isCompleted: Bool
        var dayIndex: Int?
    }
    struct CultureEntry {
        var type: String
        var title: String
        var nodes: [NodeEntry]
    }
    struct NodeEntry {
        var nodeId: String
        var name: String
        var subtitle: String
        var description: String
        var emoji: String
        var parentId: String?
        var relationType: String?
    }
    struct TipEntry {
        var content: String
        var sortIndex: Int
    }
    struct SOSEntry {
        var title: String
        var subtitle: String
        var phone: String
        var emoji: String
        var sortIndex: Int
    }

    var destination: String
    var startDate: Date
    var endDate: Date
    var days: [Day]
    var checklist: [ChecklistEntry]
    var culture: CultureEntry?
    var tips: [TipEntry]
    var sosContacts: [SOSEntry]

    // 在 ModelContext 内把纯结构体转为 SwiftData 对象
    @discardableResult
    func insertInto(context: ModelContext) -> Trip {
        let trip = Trip(destination: destination, startDate: startDate, endDate: endDate)
        context.insert(trip)

        for d in days {
            let day = TripDay(date: d.date, title: d.title, sortIndex: d.sortIndex)
            context.insert(day)
            for e in d.events {
                let event = TripEvent(
                    time: e.time, title: e.title, description: e.description,
                    locationName: e.locationName,
                    latitude: e.latitude, longitude: e.longitude,
                    eventType: e.eventType, sortIndex: e.sortIndex
                )
                context.insert(event)
                day.events.append(event)
            }
            trip.days.append(day)
        }

        for c in checklist {
            let item = ChecklistItem(title: c.title, isCompleted: c.isCompleted, dayIndex: c.dayIndex)
            context.insert(item)
            trip.checklist.append(item)
        }

        if let cu = culture {
            let cultureData = CultureData(type: cu.type, title: cu.title)
            context.insert(cultureData)
            for n in cu.nodes {
                let node = CultureNode(
                    nodeId: n.nodeId, name: n.name, subtitle: n.subtitle,
                    description: n.description, emoji: n.emoji,
                    parentId: n.parentId, relationType: n.relationType
                )
                context.insert(node)
                cultureData.nodes.append(node)
            }
            trip.culture = cultureData
        }

        for t in tips {
            let tip = Tip(content: t.content, sortIndex: t.sortIndex)
            context.insert(tip)
            trip.tips.append(tip)
        }

        for s in sosContacts {
            let sos = SOSContact(
                title: s.title, subtitle: s.subtitle,
                phone: s.phone, emoji: s.emoji, sortIndex: s.sortIndex
            )
            context.insert(sos)
            trip.sosContacts.append(sos)
        }

        return trip
    }
}

enum AIResponseParser {
    static func parse(json: String) throws -> ParsedTrip {
        guard let data = json.data(using: .utf8) else { throw ParserError.invalidJSON }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 打出具体出错位置帮助调试
            if let err = try? JSONSerialization.jsonObject(with: data) {
                print("[Parser] Unexpected type: \(type(of: err))")
            } else {
                // 用 JSONDecoder 拿到精确错误
                do {
                    _ = try JSONDecoder().decode([String: String].self, from: data)
                } catch let decodeErr {
                    print("[Parser] JSONDecodeError: \(decodeErr)")
                }
            }
            print("[Parser] Failed JSON (first 500): \(json.prefix(500))")
            throw ParserError.invalidJSON
        }
        print("[Parser] keys: \(raw.keys.sorted().joined(separator: ", "))")

        let destination = raw["destination"] as? String ?? ""
        let dateRange = raw["dateRange"] as? [String: String] ?? [:]
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let startDate = fmt.date(from: dateRange["start"] ?? "") ?? Date()
        let endDate   = fmt.date(from: dateRange["end"]   ?? "") ?? Date()

        // Days
        let rawDays = raw["itinerary"] as? [[String: Any]] ?? []
        let days: [ParsedTrip.Day] = rawDays.enumerated().map { idx, rawDay in
            let dateStr = rawDay["date"] as? String ?? ""
            let date = fmt.date(from: dateStr) ?? Date()
            let rawEvents = rawDay["events"] as? [[String: Any]] ?? []
            let events: [ParsedTrip.Event] = rawEvents.enumerated().map { eIdx, e in
                let loc = e["location"] as? [String: Any]
                return ParsedTrip.Event(
                    time: e["time"] as? String ?? "",
                    title: e["title"] as? String ?? "",
                    description: e["description"] as? String ?? "",
                    locationName: loc?["name"] as? String ?? "",
                    latitude: loc?["lat"] as? Double,
                    longitude: loc?["lng"] as? Double,
                    eventType: e["type"] as? String ?? "attraction",
                    sortIndex: eIdx
                )
            }
            return ParsedTrip.Day(
                date: date,
                title: rawDay["title"] as? String ?? "",
                sortIndex: idx,
                events: events
            )
        }

        // Checklist
        let checklist = (raw["checklist"] as? [[String: Any]] ?? []).map { item in
            ParsedTrip.ChecklistEntry(
                title: item["title"] as? String ?? "",
                isCompleted: item["completed"] as? Bool ?? false,
                dayIndex: item["dayIndex"] as? Int
            )
        }

        // Culture
        var culture: ParsedTrip.CultureEntry? = nil
        if let rc = raw["culture"] as? [String: Any] {
            let nodes = (rc["nodes"] as? [[String: Any]] ?? []).map { n in
                ParsedTrip.NodeEntry(
                    nodeId: n["id"] as? String ?? UUID().uuidString,
                    name: n["name"] as? String ?? "",
                    subtitle: n["subtitle"] as? String ?? "",
                    description: n["description"] as? String ?? "",
                    emoji: n["emoji"] as? String ?? "🏛️",
                    parentId: n["parentId"] as? String,
                    relationType: n["relationType"] as? String
                )
            }
            culture = ParsedTrip.CultureEntry(
                type: rc["type"] as? String ?? "general",
                title: rc["title"] as? String ?? "",
                nodes: nodes
            )
        }

        // Tips
        let tips = (raw["tips"] as? [String] ?? []).enumerated().map {
            ParsedTrip.TipEntry(content: $1, sortIndex: $0)
        }

        // SOS
        let sos = (raw["sos"] as? [[String: Any]] ?? []).enumerated().map { idx, s in
            ParsedTrip.SOSEntry(
                title: s["title"] as? String ?? "",
                subtitle: s["subtitle"] as? String ?? "",
                phone: s["phone"] as? String ?? "",
                emoji: s["emoji"] as? String ?? "📞",
                sortIndex: idx
            )
        }

        return ParsedTrip(
            destination: destination, startDate: startDate, endDate: endDate,
            days: days, checklist: checklist, culture: culture,
            tips: tips, sosContacts: sos
        )
    }

    enum ParserError: Error, LocalizedError {
        case invalidJSON
        var errorDescription: String? { "返回的数据格式无法识别，请重试" }
    }
}
