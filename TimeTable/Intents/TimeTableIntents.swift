import AppIntents

/// 액션 버튼·단축어에서 바로 예약 추가 화면을 연다.
struct AddAppointmentIntent: AppIntent {
    static let title: LocalizedStringResource = "예약 추가"
    static let description = IntentDescription("이번 주 시간표에서 새 예약 입력 화면을 엽니다.")
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = .addAppointment
        return .result()
    }
}

/// 액션 버튼·단축어에서 이번 주 시간표를 연다.
struct OpenTimetableIntent: AppIntent {
    static let title: LocalizedStringResource = "이번 주 시간표"
    static let description = IntentDescription("시간표 탭을 열고 이번 주로 이동합니다.")
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = .showTimetable
        return .result()
    }
}

struct TimeTableShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddAppointmentIntent(),
            phrases: [
                "\(.applicationName)에서 예약 추가",
                "\(.applicationName) 예약 추가",
            ],
            shortTitle: "예약 추가",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: OpenTimetableIntent(),
            phrases: [
                "\(.applicationName) 시간표 보기",
                "\(.applicationName) 이번 주 시간표",
            ],
            shortTitle: "이번 주 시간표",
            systemImageName: "calendar"
        )
    }
}
