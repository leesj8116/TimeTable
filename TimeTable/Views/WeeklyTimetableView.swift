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

    @State private var viewModel = TimetableViewModel()
    @State private var activeSheet: SheetState?
    @State private var showDayOffConflictAlert = false

    var body: some View {
        NavigationStack {
            TimetableGridView(
                days: viewModel.weekDays(),
                appointments: appointments(for: viewModel.currentWeekStart),
                dayOffs: allDayOffs,
                onTapAppointment: { activeSheet = .edit($0) },
                onTapSlot: { activeSheet = .add($0) },
                onToggleDayOff: toggleDayOff
            )
            .contentShape(Rectangle())
            .simultaneousGesture(weekSwipeGesture)
            .navigationTitle(viewModel.weekRangeText())
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
            .task { await holidayStore.requestAccessAndLoad() }
        }
    }

    private func appointments(for weekStart: Date) -> [Appointment] {
        let days = viewModel.weekDays(for: weekStart)
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

    private var weekSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 35, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical) * 1.25,
                      abs(horizontal) > 70 else {
                    return
                }

                if horizontal < 0 {
                    withoutAnimation {
                        viewModel.nextWeek()
                    }
                } else {
                    withoutAnimation {
                        viewModel.previousWeek()
                    }
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
