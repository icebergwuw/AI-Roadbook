import SwiftData
import Foundation

@Model
final class Trip {
    var id: UUID
    var destination: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var days: [TripDay]
    @Relationship(deleteRule: .cascade) var checklist: [ChecklistItem]
    @Relationship(deleteRule: .cascade) var culture: CultureData?
    @Relationship(deleteRule: .cascade) var tips: [Tip]
    @Relationship(deleteRule: .cascade) var sosContacts: [SOSContact]
    @Relationship(deleteRule: .cascade) var messages: [Message]

    init(destination: String, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()
        self.days = []
        self.checklist = []
        self.tips = []
        self.sosContacts = []
        self.messages = []
    }
}

@Model
final class TripDay {
    var date: Date
    var title: String
    var sortIndex: Int
    @Relationship(deleteRule: .cascade) var events: [TripEvent]

    init(date: Date, title: String, sortIndex: Int) {
        self.date = date
        self.title = title
        self.sortIndex = sortIndex
        self.events = []
    }
}

@Model
final class TripEvent: Identifiable {
    var time: String
    var title: String
    var eventDescription: String
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var eventType: String  // transport / attraction / food / accommodation
    var sortIndex: Int

    init(time: String, title: String, description: String,
         locationName: String, latitude: Double? = nil, longitude: Double? = nil,
         eventType: String = "attraction", sortIndex: Int = 0) {
        self.time = time
        self.title = title
        self.eventDescription = description
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.eventType = eventType
        self.sortIndex = sortIndex
    }
}
