import Foundation
import SwiftData

@Model
final class DayOff {
    var id: UUID
    var date: Date

    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
    }
}
