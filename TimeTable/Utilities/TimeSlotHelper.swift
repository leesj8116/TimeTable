import Foundation
import CoreGraphics

/// 시간이 겹치는 예약 묶음. 가장 긴 예약이 카드가 되고 나머지는 그 카드 안에 글자로 표시한다
struct AppointmentGroup: Identifiable {
    let host: Appointment
    let children: [Appointment]

    var id: UUID { host.id }
    var members: [Appointment] { [host] + children }
}

enum TimeSlotHelper {
    static let workStartHour  = 10
    static let workEndHour    = 20
    static let lunchStartMinutes = 12 * 60 + 30
    static let lunchEndMinutes   = 13 * 60
    static let hourHeight: CGFloat = 60  // 1pt per minute
    static let totalHours = workEndHour - workStartHour
    static let totalHeight: CGFloat = CGFloat(totalHours) * hourHeight
    static let minCellMinutes = 24  // 소요 시간이 짧아도 카드는 이 높이만큼 차지한다
    /// 예약을 시작할 수 있는 시각 (자정부터의 분, 영업시간 내 30분 단위)
    static let startSlots = Array(stride(from: workStartHour * 60, to: workEndHour * 60, by: 30))

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

    static func timeLabel(for date: Date) -> String {
        timeLabel(forMinutes: timeOfDayMinutes(for: date))
    }

    static func timeLabel(forMinutes minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// 예약을 카드 단위로 묶는다. 긴 예약부터 카드로 삼고 그와 겹치는 예약을 하위로 넣으므로
    /// 카드끼리는 겹치지 않는다. 길이가 같으면 먼저 시작하는 예약이 카드가 된다.
    static func groups(for appointments: [Appointment]) -> [AppointmentGroup] {
        var remaining = appointments.sorted {
            (-$0.durationMinutes, $0.startTime, $0.id.uuidString)
                < (-$1.durationMinutes, $1.startTime, $1.id.uuidString)
        }
        var groups: [AppointmentGroup] = []

        while !remaining.isEmpty {
            let host = remaining.removeFirst()
            let children = remaining.filter { cellsOverlap($0, host) }
            remaining.removeAll { cellsOverlap($0, host) }
            groups.append(AppointmentGroup(
                host: host,
                children: children.sorted {
                    ($0.startTime, $0.id.uuidString) < ($1.startTime, $1.id.uuidString)
                }
            ))
        }

        return groups
    }

    /// 앞 예약이 끝나는 시각에 시작하면 겹치지 않는 것으로 본다
    private static func cellsOverlap(_ a: Appointment, _ b: Appointment) -> Bool {
        a.startTime < cellEnd(of: b) && b.startTime < cellEnd(of: a)
    }

    /// 아주 짧은 예약도 카드 높이만큼 화면을 차지한다
    private static func cellEnd(of appointment: Appointment) -> Date {
        appointment.startTime.addingTimeInterval(TimeInterval(max(appointment.durationMinutes, minCellMinutes) * 60))
    }
}
