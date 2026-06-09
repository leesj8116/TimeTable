import SwiftUI

struct TimetableGridView: View {
    @Environment(HolidayStore.self) private var holidayStore

    let days: [Date]
    let appointments: [Appointment]
    let dayOffs: [DayOff]
    let onTapAppointment: (Appointment) -> Void
    let onTapSlot: (Date) -> Void
    let onToggleDayOff: (Date) -> Void

    private let gutterWidth: CGFloat = 50
    private let headerHeight: CGFloat = 50
    private let topPadding: CGFloat = 12

    private var weeklyColorMap: [String: Color] {
        let sorted = appointments.sorted { $0.startTime < $1.startTime }
        var map: [String: Color] = [:]
        var index = 0
        for appt in sorted {
            let key = appt.customerKey
            if map[key] == nil {
                map[key] = Appointment.pastelColors[index % Appointment.pastelColors.count]
                index += 1
            }
        }
        return map
    }

    var body: some View {
        GeometryReader { geo in
            let colWidth = (geo.size.width - gutterWidth) / CGFloat(days.count)

            VStack(spacing: 0) {
                headerRow(colWidth: colWidth, totalWidth: geo.size.width)

                Divider()

                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Background tap target — original full-width approach preserved for correct layout
                        Color.clear
                            .frame(width: geo.size.width, height: TimeSlotHelper.totalHeight + topPadding)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture(coordinateSpace: .local)
                                    .onEnded { value in
                                        let x = value.location.x - gutterWidth
                                        let y = value.location.y
                                        guard x >= 0 else { return }
                                        let col = Int(x / colWidth)
                                        guard col >= 0, col < days.count else { return }
                                        guard !isDayOff(days[col]) else { return }
                                        if let date = dateFromTap(x: x, y: y, colWidth: colWidth) {
                                            onTapSlot(date)
                                        }
                                    }
                            )

                        gridBackground(colWidth: colWidth, totalWidth: geo.size.width, topPadding: topPadding)
                            .allowsHitTesting(false)

                        // Day-off column overlays (no hit testing — tap passes through to background)
                        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                            if isDayOff(day) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.systemGray4).opacity(0.85))
                                    Text("휴무")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color(.systemGray))
                                }
                                .frame(width: colWidth - 1, height: TimeSlotHelper.totalHeight)
                                .offset(x: gutterWidth + CGFloat(index) * colWidth + 0.5, y: topPadding)
                                .allowsHitTesting(false)
                            }
                        }

                        ForEach(appointments) { appt in
                            if let col = columnIndex(for: appt.startTime), !isDayOff(days[col]) {
                                let x = gutterWidth + CGFloat(col) * colWidth + 2
                                let y = TimeSlotHelper.yOffset(for: appt.startTime) + topPadding
                                let h = max(TimeSlotHelper.height(forMinutes: appt.durationMinutes), 24)

                                AppointmentCellView(
                                    appointment: appt,
                                    width: colWidth - 4,
                                    color: weeklyColorMap[appt.customerKey] ?? Appointment.pastelColors[0]
                                )
                                    .frame(height: h)
                                    .offset(x: x, y: y)
                                    .onTapGesture { onTapAppointment(appt) }
                            }
                        }
                    }
                    .frame(height: TimeSlotHelper.totalHeight + topPadding, alignment: .topLeading)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerRow(colWidth: CGFloat, totalWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth, height: headerHeight)

            ForEach(days, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(weekdayLabel(for: day))
                        .font(.caption2)
                        .foregroundStyle(isToday(day) ? Color.accentColor : holidayStore.isHoliday(day) ? .red : Color.secondary)
                    Text(dayString(for: day))
                        .font(.subheadline)
                        .fontWeight(isToday(day) ? .bold : .regular)
                        .foregroundStyle(isToday(day) ? Color.white : holidayStore.isHoliday(day) ? .red : Color.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            if isToday(day) {
                                Capsule()
                                    .fill(Color.accentColor)
                            }
                        }
                }
                .frame(width: colWidth, height: headerHeight)
                .contentShape(Rectangle())
                .contextMenu {
                    if isDayOff(day) {
                        Button(role: .destructive) {
                            onToggleDayOff(day)
                        } label: {
                            Label("휴무 해제", systemImage: "sun.max")
                        }
                    } else {
                        Button {
                            onToggleDayOff(day)
                        } label: {
                            Label("휴무 지정", systemImage: "moon.zzz")
                        }
                    }
                }
            }
        }
        .frame(width: totalWidth)
    }

    // MARK: - Grid Background

    @ViewBuilder
    private func gridBackground(colWidth: CGFloat, totalWidth: CGFloat, topPadding: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
            if isToday(day) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.055))
                    .frame(width: colWidth, height: TimeSlotHelper.totalHeight)
                    .offset(x: gutterWidth + CGFloat(index) * colWidth, y: topPadding)
            }
        }

        ForEach(0..<TimeSlotHelper.totalHours, id: \.self) { offset in
            let hour = TimeSlotHelper.workStartHour + offset
            let y    = CGFloat(offset) * TimeSlotHelper.hourHeight + topPadding

            Text("\(hour % 12 == 0 ? 12 : hour % 12)시")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: gutterWidth - 6, alignment: .trailing)
                .offset(x: 0, y: y - 8)

            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.4))
                .frame(width: totalWidth - gutterWidth, height: 0.5)
                .offset(x: gutterWidth, y: y)
        }

        ForEach(0...days.count, id: \.self) { col in
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.3))
                .frame(width: 0.5, height: TimeSlotHelper.totalHeight)
                .offset(x: gutterWidth + CGFloat(col) * colWidth, y: topPadding)
        }

        let lunchY = CGFloat(TimeSlotHelper.lunchStartMinutes - TimeSlotHelper.workStartHour * 60) + topPadding
        let lunchHeight = CGFloat(TimeSlotHelper.lunchEndMinutes - TimeSlotHelper.lunchStartMinutes)
        Rectangle()
            .fill(Color(uiColor: .systemGray5))
            .frame(width: totalWidth - gutterWidth, height: lunchHeight)
            .offset(x: gutterWidth, y: lunchY)
        Text("점심")
            .font(.caption2)
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
            .offset(x: gutterWidth + 4, y: lunchY + 4)
    }

    // MARK: - Tap → Date

    private func dateFromTap(x: CGFloat, y: CGFloat, colWidth: CGFloat) -> Date? {
        let col = Int(x / colWidth)
        guard col >= 0, col < days.count else { return nil }

        let minutesFromTop = y - topPadding
        guard minutesFromTop >= 0 else { return nil }

        let snapped = Int(minutesFromTop / 60) * 60
        guard snapped < TimeSlotHelper.totalHours * 60 else { return nil }

        let hour   = TimeSlotHelper.workStartHour + snapped / 60
        let minute = snapped % 60

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: days[col])
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps)
    }

    // MARK: - Helpers

    private func isDayOff(_ date: Date) -> Bool {
        let cal = Calendar.current
        return dayOffs.contains { cal.isDate($0.date, inSameDayAs: date) }
    }

    private func columnIndex(for date: Date) -> Int? {
        let cal = Calendar.current
        return days.firstIndex(where: { cal.isDate($0, inSameDayAs: date) })
    }

    private func weekdayString(for date: Date) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        let idx = Calendar.current.component(.weekday, from: date)
        return names[idx - 1]
    }

    private func weekdayLabel(for date: Date) -> String {
        let base = weekdayString(for: date)
        if let label = holidayStore.specialLabel(date) {
            return "\(base) (\(label))"
        }
        return base
    }

    private func dayString(for date: Date) -> String {
        return "\(Calendar.current.component(.day, from: date))"
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
