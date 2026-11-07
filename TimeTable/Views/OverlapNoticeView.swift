import SwiftUI

/// 예약 폼에서 시간이 겹치는 예약을 알려준다. 겹쳐도 저장은 할 수 있다.
struct OverlapNoticeView: View {
    let appointments: [Appointment]

    var body: some View {
        if !appointments.isEmpty {
            Label {
                Text("시간이 겹치는 예약: \(summary)")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var summary: String {
        appointments
            .map { "\($0.displayDogName) \($0.timeRangeText)" }
            .joined(separator: ", ")
    }
}
