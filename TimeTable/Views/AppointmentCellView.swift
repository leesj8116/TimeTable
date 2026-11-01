import SwiftUI

struct AppointmentCellView: View {
    let appointment: Appointment
    let width: CGFloat
    let color: Color
    var isHighlighted = false

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
                VStack(alignment: .leading, spacing: 1) {
                    let parts = appointment.dogNameParts
                    Text(parts.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let code = parts.code {
                        Text(code)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    Text(appointment.serviceType.rawValue)
                        .font(.caption2)
                        .fixedSize(horizontal: false, vertical: true)
                    if !appointment.memo.isEmpty {
                        Text(appointment.memo)
                            .font(.caption2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
            }
            .frame(width: width)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }
}
