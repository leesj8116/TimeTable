import Observation

/// 앱 외부(액션 버튼, 단축어)에서 들어온 요청을 화면으로 전달하는 라우터.
@Observable
final class AppRouter {
    enum Action: Equatable {
        case addAppointment
        case showTimetable
    }

    static let shared = AppRouter()

    var pendingAction: Action?
}
