import Foundation
import Observation

@Observable
final class TimetableViewModel {
    var currentWeekStart: Date

    init() {
        let today = Date()
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current
        let weekday = cal.component(.weekday, from: today) // Sun=1, Mon=2, Tue=3…Sat=7
        if weekday == 1 || weekday == 2 {
            let offset = weekday == 1 ? 2 : 1
            let nextTuesday = cal.date(byAdding: .day, value: offset, to: today) ?? today
            currentWeekStart = TimetableViewModel.startOfWeek(for: nextTuesday)
        } else {
            currentWeekStart = TimetableViewModel.startOfWeek(for: today)
        }
    }

    static func startOfWeek(for date: Date) -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }

    func weekStart(offsetByWeeks offset: Int) -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current
        return cal.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart) ?? currentWeekStart
    }

    /// Returns [Tue, Wed, Thu, Fri, Sat] for the current week
    func weekDays() -> [Date] {
        weekDays(for: currentWeekStart)
    }

    /// Returns [Tue, Wed, Thu, Fri, Sat] for a specific ISO week start date.
    /// includeMonday이면 추가 근무일인 월요일을 앞에 붙여 [Mon … Sat]을 반환한다.
    func weekDays(for weekStart: Date, includeMonday: Bool = false) -> [Date] {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current
        // ISO week starts Monday (offset 0). Tuesday = +1 … Saturday = +5
        let offsets = includeMonday ? 0...5 : 1...5
        return offsets.compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    /// ISO 주 시작일이 곧 그 주의 월요일이다
    func monday(for weekStart: Date) -> Date {
        Calendar.current.startOfDay(for: weekStart)
    }

    /// 정규 근무일(화~토)이거나 추가 근무일로 지정된 날이면 true
    static func isWorkDay(_ date: Date, extraWorkDays: [ExtraWorkDay]) -> Bool {
        let cal = Calendar.current
        return TimeSlotHelper.isWorkDay(date)
            || extraWorkDays.contains { cal.isDate($0.date, inSameDayAs: date) }
    }

    func previousWeek() {
        currentWeekStart = Calendar(identifier: .iso8601)
            .date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
    }

    func nextWeek() {
        currentWeekStart = Calendar(identifier: .iso8601)
            .date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? currentWeekStart
    }

    func goToCurrentWeek() {
        currentWeekStart = TimetableViewModel.startOfWeek(for: Date())
    }

    func weekRangeText() -> String {
        weekRangeText(for: currentWeekStart)
    }

    func weekRangeText(for weekStart: Date, includeMonday: Bool = false) -> String {
        let days = weekDays(for: weekStart, includeMonday: includeMonday)
        guard let first = days.first, let last = days.last else { return "" }
        let cal = Calendar.current
        let firstMonth = cal.component(.month, from: first)
        let lastMonth  = cal.component(.month, from: last)
        if firstMonth == lastMonth {
            return "\(firstMonth)월"
        } else {
            return "\(firstMonth)월 ~ \(lastMonth)월"
        }
    }

    /// Returns true if the proposed time slot is bookable
    func canBook(
        startTime: Date,
        durationMinutes: Int,
        excluding id: UUID? = nil,
        existing: [Appointment],
        dayOffs: [DayOff] = [],
        extraWorkDays: [ExtraWorkDay] = []
    ) -> Bool {
        let cal = Calendar.current
        let endTime = cal.date(byAdding: .minute, value: durationMinutes, to: startTime)!

        let startMin = TimeSlotHelper.timeOfDayMinutes(for: startTime)
        let endMin   = TimeSlotHelper.timeOfDayMinutes(for: endTime)

        // Reject if day is marked as day off
        if dayOffs.contains(where: { cal.isDate($0.date, inSameDayAs: startTime) }) { return false }

        // Within working hours
        guard startMin >= TimeSlotHelper.workStartHour * 60,
              endMin   <= TimeSlotHelper.workEndHour   * 60 else { return false }

        // Must be a work day (Tue–Sat, or an extra work day)
        guard TimetableViewModel.isWorkDay(startTime, extraWorkDays: extraWorkDays) else { return false }

        // No overlap with existing appointments on the same day
        let sameDay = existing.filter {
            cal.isDate($0.startTime, inSameDayAs: startTime) && $0.id != id
        }
        for appt in sameDay {
            let s = TimeSlotHelper.timeOfDayMinutes(for: appt.startTime)
            let e = TimeSlotHelper.timeOfDayMinutes(for: appt.endTime)
            if startMin < e && endMin > s { return false }
        }

        return true
    }
}
