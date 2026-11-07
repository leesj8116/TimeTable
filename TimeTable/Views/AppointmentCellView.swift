import SwiftUI

struct AppointmentCellView: View {
    let appointment: Appointment
    let width: CGFloat
    let color: Color
    var isHighlighted = false
    /// 이 예약과 시간이 겹쳐 카드 안에 글자로 표시할 예약
    var children: [Appointment] = []
    /// 고객별 색. 하위 예약 줄을 큰 예약과 구분하는 데 쓴다
    var customerColors: [String: Color] = [:]

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color.opacity(0.85))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.tint, lineWidth: 3)
                    .opacity(isHighlighted ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.3), value: isHighlighted)
            .overlay(alignment: .topLeading) {
                Group {
                    if children.isEmpty {
                        hostDetails(showsCode: true, showsService: true, showsMemo: true)
                            .padding(.vertical, 3)
                    } else {
                        // 카드 높이 안에 들어가는 가장 자세한 표시를 고른다
                        ViewThatFits(in: .vertical) {
                            tree(showsCode: true, showsService: true, showsMemo: true, showsChildDetail: true)
                                .padding(.vertical, 3)
                            tree(showsCode: true, showsService: true, showsChildDetail: true)
                                .padding(.vertical, 3)
                            tree(showsService: true, showsChildDetail: true)
                                .padding(.vertical, 3)
                            tree(showsCode: true, showsService: true)
                                .padding(.vertical, 3)
                            tree(showsService: true)
                                .padding(.vertical, 3)
                            tree()
                            childCountSummary
                        }
                    }
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 5)
            }
            .frame(width: width)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }

    private func hostDetails(showsCode: Bool = false, showsService: Bool = false, showsMemo: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            let parts = appointment.dogNameParts
            Text(parts.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            if showsCode, let code = parts.code {
                Text(code)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            if showsService {
                Text(appointment.serviceType.rawValue)
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsMemo, !appointment.memo.isEmpty {
                Text(appointment.memo)
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tree(
        showsCode: Bool = false,
        showsService: Bool = false,
        showsMemo: Bool = false,
        showsChildDetail: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            hostDetails(showsCode: showsCode, showsService: showsService, showsMemo: showsMemo)
            ForEach(children) { child in
                childRow(child, showsDetail: showsChildDetail)
            }
        }
    }

    private func childRow(_ child: Appointment, showsDetail: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(child.id == children.last?.id ? "└" : "├")
            VStack(alignment: .leading, spacing: 0) {
                Text(child.dogNameParts.name)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if showsDetail {
                    Text(detailText(for: child))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    if !child.memo.isEmpty {
                        Text(child.memo)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // 같은 고객이면 색이 같으므로 테두리로도 구분한다
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(customerColors[child.customerKey] ?? .white)
                    .strokeBorder(.white.opacity(0.8), lineWidth: 1)
            }
        }
        .font(.caption2)
    }

    private var childCountSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            hostDetails()
            Text("└ \(children.count)건")
                .font(.caption2)
                .fontWeight(.semibold)
        }
    }

    private func detailText(for child: Appointment) -> String {
        // 카드가 끝난 뒤까지 이어지는 예약은 시간표에서 보이지 않으므로 끝나는 시각도 적는다
        let time = child.endTime > appointment.endTime
            ? child.timeRangeText
            : TimeSlotHelper.timeLabel(for: child.startTime)
        return "\(time) \(child.serviceType.rawValue)"
    }
}
