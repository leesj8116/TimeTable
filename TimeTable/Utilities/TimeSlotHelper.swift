import Foundation
import CoreGraphics

enum TimeSlotHelper {
    static let workStartHour  = 10
    static let workEndHour    = 20
    static let lunchStartMinutes = 12 * 60 + 30
    static let lunchEndMinutes   = 13 * 60
    static let hourHeight: CGFloat = 60  // 1pt per minute
    static let totalHours = workEndHour - workStartHour
    static let totalHeight: CGFloat = CGFloat(totalHours) * hourHeight

    /// Pixel offset from the top of the grid for a given time-of-day
    static func yOffset(for date: Date) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutesFromStart = (comps.hour! - workStartHour) * 60 + comps.minute!
        return CGFloat(minutesFromStart)
    }

    static func height(forMinutes minutes: Int) -> CGFloat {
        CGFloat(minutes)
    }

    static func timeOfDayMinutes(for date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    /// Returns true if the date falls on Tue–Sat (weekday 3–7)
    static func isWorkDay(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return (3...7).contains(weekday)
    }
}
