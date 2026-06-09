import EventKit
import Foundation
import Observation

@Observable
final class HolidayStore {
    private let store = EKEventStore()
    private(set) var holidays: [String: String] = [:]

    private static let dateKey: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    func requestAccessAndLoad() async {
        let granted: Bool
        do {
            granted = try await store.requestFullAccessToEvents()
        } catch {
            return
        }
        guard granted else { return }
        loadHolidays()
    }

    func isHoliday(_ date: Date) -> Bool {
        holidays[key(for: date)] != nil
    }

    /// 이벤트 제목에 "설날" 또는 "추석"이 포함된 경우 해당 문자열 반환
    func specialLabel(_ date: Date) -> String? {
        guard let title = holidays[key(for: date)] else { return nil }
        if title.contains("설날") { return "설날" }
        if title.contains("추석") { return "추석" }
        return nil
    }

    private func key(for date: Date) -> String {
        Self.dateKey.string(from: date)
    }

    private func loadHolidays() {
        let holidayCalendars = store.calendars(for: .event).filter {
            $0.title.contains("공휴일")
        }
        guard !holidayCalendars.isEmpty else { return }

        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .year, value: -2, to: now) ?? now
        let end   = cal.date(byAdding: .year, value:  2, to: now) ?? now

        let predicate = store.predicateForEvents(
            withStart: start,
            end: end,
            calendars: holidayCalendars
        )
        let events = store.events(matching: predicate)

        var result: [String: String] = [:]
        for event in events {
            let k = key(for: event.startDate)
            result[k] = event.title
        }
        holidays = result
    }
}
