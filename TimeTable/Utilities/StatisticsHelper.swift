import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case weekly  = "주간"
    case monthly = "월간"

    var id: String { rawValue }

    /// 주간: 최근 8주, 월간: 최근 6개월
    var bucketCount: Int {
        switch self {
        case .weekly:  return 8
        case .monthly: return 6
        }
    }
}

/// 기간별 예약 건수 버킷
struct PeriodCount: Identifiable {
    let periodStart: Date
    let label: String
    let count: Int
    let isCurrent: Bool

    var id: Date { periodStart }
}

/// 서비스 유형별 비중
struct ServiceShare: Identifiable {
    let service: ServiceType
    let count: Int
    let ratio: Double

    var id: String { service.rawValue }
}

/// 요일·시간대 히트맵 셀
struct WeekdayHourCell: Identifiable {
    let weekdaySymbol: String
    let hour: Int
    let count: Int

    var id: String { "\(weekdaySymbol)-\(hour)" }
}

/// 단골 고객 순위 항목
struct TopCustomer: Identifiable {
    let key: String
    let displayName: String
    let dog: Dog?
    let count: Int
    let lastVisit: Date
    /// 과거 방문 없이 앞으로의 예약만 있는 고객
    let isUpcomingOnly: Bool

    var id: String { key }
}

enum StatisticsHelper {
    static let workdaySymbols = ["화", "수", "목", "금", "토"]

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "ko_KR")
        return cal
    }

    /// 선택된 기간의 집계 윈도우 [시작, 현재 주/월의 끝).
    /// 현재 주/월에 속한 미래 예약도 집계에 포함된다.
    static func window(for period: StatsPeriod, now: Date = .now) -> Range<Date> {
        let cal = calendar
        let currentStart = bucketStart(for: now, period: period)
        switch period {
        case .weekly:
            let start = cal.date(byAdding: .weekOfYear, value: -(period.bucketCount - 1), to: currentStart) ?? currentStart
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: currentStart) ?? currentStart
            return start..<end
        case .monthly:
            let start = cal.date(byAdding: .month, value: -(period.bucketCount - 1), to: currentStart) ?? currentStart
            let end = cal.date(byAdding: .month, value: 1, to: currentStart) ?? currentStart
            return start..<end
        }
    }

    static func appointments(_ appointments: [Appointment], in window: Range<Date>) -> [Appointment] {
        appointments.filter { window.contains($0.startTime) }
    }

    /// 기간별 예약 건수. 0건인 기간도 버킷으로 포함해 빈 막대로 렌더링된다.
    static func periodCounts(_ appointments: [Appointment], period: StatsPeriod, now: Date = .now) -> [PeriodCount] {
        let cal = calendar
        let currentStart = bucketStart(for: now, period: period)
        let starts: [Date] = (0..<period.bucketCount).reversed().compactMap { offset in
            switch period {
            case .weekly:  return cal.date(byAdding: .weekOfYear, value: -offset, to: currentStart)
            case .monthly: return cal.date(byAdding: .month, value: -offset, to: currentStart)
            }
        }
        let grouped = Dictionary(grouping: appointments) { bucketStart(for: $0.startTime, period: period) }
        return starts.map { start in
            PeriodCount(
                periodStart: start,
                label: label(for: start, period: period),
                count: grouped[start]?.count ?? 0,
                isCurrent: start == currentStart
            )
        }
    }

    static func serviceShares(_ appointments: [Appointment]) -> [ServiceShare] {
        guard !appointments.isEmpty else { return [] }
        let total = appointments.count
        let grouped = Dictionary(grouping: appointments) { $0.serviceType }
        return ServiceType.allCases
            .compactMap { service -> ServiceShare? in
                guard let count = grouped[service]?.count, count > 0 else { return nil }
                return ServiceShare(service: service, count: count, ratio: Double(count) / Double(total))
            }
            .sorted { $0.count > $1.count }
    }

    /// 화~토 × 영업시간(10~19시) 전체 그리드. 비영업일 예약은 제외한다.
    static func weekdayHourGrid(_ appointments: [Appointment]) -> [WeekdayHourCell] {
        let cal = Calendar.current
        let hours = TimeSlotHelper.workStartHour..<TimeSlotHelper.workEndHour
        var counts: [String: Int] = [:]
        for appt in appointments where TimeSlotHelper.isWorkDay(appt.startTime) {
            let weekday = cal.component(.weekday, from: appt.startTime) // 화=3 … 토=7
            let hour = cal.component(.hour, from: appt.startTime)
            guard hours.contains(hour) else { continue }
            let symbol = workdaySymbols[weekday - 3]
            counts["\(symbol)-\(hour)", default: 0] += 1
        }
        return workdaySymbols.flatMap { symbol in
            hours.map { hour in
                WeekdayHourCell(weekdaySymbol: symbol, hour: hour, count: counts["\(symbol)-\(hour)"] ?? 0)
            }
        }
    }

    /// customerKey로 그룹핑해 방문 횟수 순으로 정렬. 회원 미연결 예약도 포함된다.
    static func topCustomers(_ appointments: [Appointment], limit: Int = 10, now: Date = .now) -> [TopCustomer] {
        let grouped = Dictionary(grouping: appointments) { $0.customerKey }
        let customers = grouped.map { key, appts -> TopCustomer in
            let dog = appts.compactMap(\.dog).first
            let displayName: String
            if let dog {
                displayName = dog.latestDogName.isEmpty ? dog.name : "\(dog.latestDogName)(\(dog.name))"
            } else {
                displayName = appts.first?.dogName ?? key
            }
            let allTimes = appts.map(\.startTime)
            let pastTimes = allTimes.filter { $0 <= now }
            return TopCustomer(
                key: key,
                displayName: displayName,
                dog: dog,
                count: appts.count,
                lastVisit: pastTimes.max() ?? allTimes.max() ?? now,
                isUpcomingOnly: pastTimes.isEmpty
            )
        }
        return customers
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.lastVisit > $1.lastVisit
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func bucketStart(for date: Date, period: StatsPeriod) -> Date {
        switch period {
        case .weekly:
            return TimetableViewModel.startOfWeek(for: date)
        case .monthly:
            let cal = calendar
            let comps = cal.dateComponents([.year, .month], from: date)
            return cal.date(from: comps) ?? date
        }
    }

    private static func label(for bucketStart: Date, period: StatsPeriod) -> String {
        let cal = calendar
        switch period {
        case .weekly:
            // 영업 시작 요일(화요일) 날짜로 표기해 시간표 탭과 일치시킨다
            let tuesday = cal.date(byAdding: .day, value: 1, to: bucketStart) ?? bucketStart
            let comps = cal.dateComponents([.month, .day], from: tuesday)
            return "\(comps.month ?? 0)/\(comps.day ?? 0)~"
        case .monthly:
            let month = cal.component(.month, from: bucketStart)
            return "\(month)월"
        }
    }
}
