import SwiftUI
import SwiftData

private enum SheetState: Identifiable {
    case add(Date?)
    case edit(Appointment)

    var id: String {
        switch self {
        case .add(let d):  return "add-\(d?.timeIntervalSince1970 ?? 0)"
        case .edit(let a): return "edit-\(a.id)"
        }
    }
}

struct WeeklyTimetableView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HolidayStore.self) private var holidayStore
    @Query private var allAppointments: [Appointment]
    @Query private var allDayOffs: [DayOff]
    @Query private var allExtraWorkDays: [ExtraWorkDay]

    @State private var viewModel = TimetableViewModel()
    @State private var activeSheet: SheetState?
    @State private var showDayOffConflictAlert = false
    @State private var showMondayConflictAlert = false

    var body: some View {
        NavigationStack {
            TimetableGridView(
                days: visibleDays(for: viewModel.currentWeekStart),
                appointments: appointments(for: viewModel.currentWeekStart),
                dayOffs: allDayOffs,
                onTapAppointment: { activeSheet = .edit($0) },
                onTapSlot: { activeSheet = .add($0) },
                onToggleDayOff: toggleDayOff,
                onSwipeWeek: swipeWeek
            )
            .navigationTitle(viewModel.weekRangeText(
                for: viewModel.currentWeekStart,
                includeMonday: showsMonday(for: viewModel.currentWeekStart)
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Button { moveToPreviousWeek() } label: {
                            Image(systemName: "chevron.left")
                        }
                        Button("오늘") { goToCurrentWeek() }
                            .font(.subheadline)
                        Button { moveToNextWeek() } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    let isOn = isMondayWorkDay(for: viewModel.currentWeekStart)
                    Button { toggleMondayWork() } label: {
                        Text("월")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(isOn ? Color.white : Color.secondary)
                            .frame(width: 28, height: 28)
                            .background {
                                if isOn {
                                    Circle().fill(Color.accentColor)
                                }
                            }
                    }
                    .accessibilityLabel(isOn ? "이번 주 월요일 근무 해제" : "이번 주 월요일 근무 추가")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .add(nil) } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add(let date):
                    AddAppointmentView(defaultDate: date, viewModel: viewModel)
                case .edit(let appointment):
                    EditAppointmentView(appointment: appointment, viewModel: viewModel)
                }
            }
            .alert("휴무 지정 불가", isPresented: $showDayOffConflictAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("이 날에 이미 예약이 있습니다.\n예약을 먼저 삭제하거나 이동한 뒤 휴무를 지정하세요.")
            }
            .alert("월요일 근무 해제 불가", isPresented: $showMondayConflictAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("이번 주 월요일에 예약이 있습니다.\n예약을 먼저 삭제하거나 이동한 뒤 근무를 해제하세요.")
            }
            .task { await holidayStore.requestAccessAndLoad() }
        }
    }

    /// 월요일은 추가 근무일로 지정했거나 예약이 있는 주에만 표시한다
    private func visibleDays(for weekStart: Date) -> [Date] {
        viewModel.weekDays(for: weekStart, includeMonday: showsMonday(for: weekStart))
    }

    private func showsMonday(for weekStart: Date) -> Bool {
        isMondayWorkDay(for: weekStart) || hasMondayAppointments(for: weekStart)
    }

    private func isMondayWorkDay(for weekStart: Date) -> Bool {
        let monday = viewModel.monday(for: weekStart)
        return allExtraWorkDays.contains { Calendar.current.isDate($0.date, inSameDayAs: monday) }
    }

    private func hasMondayAppointments(for weekStart: Date) -> Bool {
        let monday = viewModel.monday(for: weekStart)
        return allAppointments.contains { Calendar.current.isDate($0.startTime, inSameDayAs: monday) }
    }

    private func toggleMondayWork() {
        let cal = Calendar.current
        let monday = viewModel.monday(for: viewModel.currentWeekStart)

        if let existing = allExtraWorkDays.first(where: { cal.isDate($0.date, inSameDayAs: monday) }) {
            if hasMondayAppointments(for: viewModel.currentWeekStart) {
                showMondayConflictAlert = true
            } else {
                withoutAnimation { modelContext.delete(existing) }
            }
        } else {
            withoutAnimation { modelContext.insert(ExtraWorkDay(date: monday)) }
        }
    }

    private func appointments(for weekStart: Date) -> [Appointment] {
        let days = visibleDays(for: weekStart)
        guard let first = days.first, let last = days.last else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: first)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: last))!
        return allAppointments.filter { $0.startTime >= start && $0.startTime < end }
    }

    private func toggleDayOff(_ date: Date) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)

        if let existing = allDayOffs.first(where: { cal.isDate($0.date, inSameDayAs: startOfDay) }) {
            modelContext.delete(existing)
        } else {
            let hasAppointments = allAppointments.contains { cal.isDate($0.startTime, inSameDayAs: startOfDay) }
            if hasAppointments {
                showDayOffConflictAlert = true
            } else {
                modelContext.insert(DayOff(date: startOfDay))
            }
        }
    }

    private func moveToPreviousWeek() {
        withoutAnimation {
            viewModel.previousWeek()
        }
    }

    private func moveToNextWeek() {
        withoutAnimation {
            viewModel.nextWeek()
        }
    }

    private func goToCurrentWeek() {
        withoutAnimation {
            viewModel.goToCurrentWeek()
        }
    }

    private func swipeWeek(_ direction: Int) {
        withoutAnimation {
            if direction > 0 {
                viewModel.nextWeek()
            } else {
                viewModel.previousWeek()
            }
        }
    }

    private func withoutAnimation(_ action: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            action()
        }
    }
}
