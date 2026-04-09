import SwiftData
import Foundation

@Observable
final class NewTripViewModel {
    var destination: String = ""
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var selectedStyle: TravelStyle = .cultural
    var isGenerating: Bool = false
    var errorMessage: String? = nil

    enum TravelStyle: String, CaseIterable {
        case cultural = "文化深度"
        case leisure = "休闲放松"
        case adventure = "探险挑战"

        var apiValue: String {
            switch self {
            case .cultural: return "cultural"
            case .leisure: return "leisure"
            case .adventure: return "adventure"
            }
        }
    }

    var isValid: Bool {
        !destination.trimmingCharacters(in: .whitespaces).isEmpty && endDate > startDate
    }

    func generate(context: ModelContext) async {
        guard isValid else { return }
        isGenerating = true
        errorMessage = nil

        do {
            let json = try await AIService.generateTrip(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                style: selectedStyle.apiValue
            )
            let parsed = try AIResponseParser.parse(json: json)
            let trip = Trip(destination: parsed.destination, startDate: parsed.startDate, endDate: parsed.endDate)
            trip.days = parsed.days
            trip.checklist = parsed.checklist
            trip.culture = parsed.culture
            trip.tips = parsed.tips
            trip.sosContacts = parsed.sosContacts
            context.insert(trip)
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }
}
