import Foundation

struct ParsedTrip {
    var destination: String
    var startDate: Date
    var endDate: Date
    var days: [TripDay]
    var checklist: [ChecklistItem]
    var culture: CultureData?
    var tips: [Tip]
    var sosContacts: [SOSContact]
}

enum AIResponseParser {
    static func parse(json: String) throws -> ParsedTrip {
        guard let data = json.data(using: .utf8) else {
            throw ParserError.invalidJSON
        }
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let raw else { throw ParserError.invalidJSON }

        let destination = raw["destination"] as? String ?? ""

        let dateRange = raw["dateRange"] as? [String: String] ?? [:]
        let formatter = ISO8601DateFormatter()
        let startDate = formatter.date(from: dateRange["start"] ?? "") ?? Date()
        let endDate = formatter.date(from: dateRange["end"] ?? "") ?? Date()

        // Parse itinerary
        let rawDays = raw["itinerary"] as? [[String: Any]] ?? []
        let days: [TripDay] = rawDays.enumerated().map { idx, rawDay in
            let dateStr = rawDay["date"] as? String ?? ""
            let date = formatter.date(from: dateStr) ?? Date()
            let day = TripDay(
                date: date,
                title: rawDay["title"] as? String ?? "",
                sortIndex: idx
            )
            let rawEvents = rawDay["events"] as? [[String: Any]] ?? []
            day.events = rawEvents.enumerated().map { eIdx, rawEvent in
                let loc = rawEvent["location"] as? [String: Any]
                return TripEvent(
                    time: rawEvent["time"] as? String ?? "",
                    title: rawEvent["title"] as? String ?? "",
                    description: rawEvent["description"] as? String ?? "",
                    locationName: loc?["name"] as? String ?? "",
                    latitude: loc?["lat"] as? Double,
                    longitude: loc?["lng"] as? Double,
                    eventType: rawEvent["type"] as? String ?? "attraction",
                    sortIndex: eIdx
                )
            }
            return day
        }

        // Parse checklist
        let rawChecklist = raw["checklist"] as? [[String: Any]] ?? []
        let checklist: [ChecklistItem] = rawChecklist.map { item in
            ChecklistItem(
                title: item["title"] as? String ?? "",
                isCompleted: item["completed"] as? Bool ?? false,
                dayIndex: item["dayIndex"] as? Int
            )
        }

        // Parse culture
        var culture: CultureData? = nil
        if let rawCulture = raw["culture"] as? [String: Any] {
            let c = CultureData(
                type: rawCulture["type"] as? String ?? "general",
                title: rawCulture["title"] as? String ?? ""
            )
            let rawNodes = rawCulture["nodes"] as? [[String: Any]] ?? []
            c.nodes = rawNodes.map { n in
                CultureNode(
                    nodeId: n["id"] as? String ?? UUID().uuidString,
                    name: n["name"] as? String ?? "",
                    subtitle: n["subtitle"] as? String ?? "",
                    description: n["description"] as? String ?? "",
                    emoji: n["emoji"] as? String ?? "🏛️",
                    parentId: n["parentId"] as? String,
                    relationType: n["relationType"] as? String
                )
            }
            culture = c
        }

        // Parse tips
        let rawTips = raw["tips"] as? [String] ?? []
        let tips: [Tip] = rawTips.enumerated().map { idx, t in
            Tip(content: t, sortIndex: idx)
        }

        // Parse SOS
        let rawSOS = raw["sos"] as? [[String: Any]] ?? []
        let sos: [SOSContact] = rawSOS.enumerated().map { idx, s in
            SOSContact(
                title: s["title"] as? String ?? "",
                subtitle: s["subtitle"] as? String ?? "",
                phone: s["phone"] as? String ?? "",
                emoji: s["emoji"] as? String ?? "📞",
                sortIndex: idx
            )
        }

        return ParsedTrip(
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            days: days,
            checklist: checklist,
            culture: culture,
            tips: tips,
            sosContacts: sos
        )
    }

    enum ParserError: Error {
        case invalidJSON
    }
}
