import SwiftUI

/// 예약 시작 시각을 영업시간 내 30분 단위로 고른다. 값은 자정부터의 분이다
struct StartTimePicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("시작 시간", selection: $selection) {
            ForEach(TimeSlotHelper.startSlots, id: \.self) { minutes in
                Text(TimeSlotHelper.timeLabel(forMinutes: minutes)).tag(minutes)
            }
        }
        .pickerStyle(.menu)
    }
}
