import Foundation
import SwiftData

/// 정규 근무일(화~토) 외에 추가로 근무하는 날 (예: 월요일)
@Model
final class ExtraWorkDay {
    var id: UUID
    var date: Date

    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
    }
}
