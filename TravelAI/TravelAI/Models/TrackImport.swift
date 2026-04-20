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
    var isPhotoTrack: Bool          // 由照片GPS自动生成，不允许用户手动删除
    @Relationship(deleteRule: .cascade, inverse: \TrackPoint.trackImport)
    var points: [TrackPoint]

    init(fileName: String, fileFormat: String, isPhotoTrack: Bool = false) {
        self.id = UUID()
        self.fileName = fileName
        self.importedAt = Date()
        self.fileFormat = fileFormat
        self.totalPoints = 0
        self.daySpan = 0
        self.isVisible = true
        self.isPhotoTrack = isPhotoTrack
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

// Temporary intermediate struct, not stored in SwiftData
struct RawTrackPoint: Sendable {
    let latitude, longitude: Double
    let altitude: Double?
    let timestamp: Date?
}
