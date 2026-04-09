import SwiftData
import Foundation

@Observable
final class HomeViewModel {
    func delete(_ trip: Trip, context: ModelContext) {
        context.delete(trip)
        try? context.save()
    }
}
