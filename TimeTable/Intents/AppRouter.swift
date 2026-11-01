import Foundation
import Observation

/// 앱 외부(액션 버튼, 단축어)나 다른 탭에서 들어온 요청을 시간표 화면으로 전달하는 라우터.
@Observable
final class AppRouter {
    enum Action: Equatable {
        case addAppointment
        case showTimetable
        /// 회원 방문 기록에서 선택한 예약이 있는 주로 이동해 강조한다
        case showAppointment(id: UUID, date: Date)
    }

    static let shared = AppRouter()

    var pendingAction: Action?
}
