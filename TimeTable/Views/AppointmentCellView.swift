import SwiftUI

struct AppointmentCellView: View {
    let appointment: Appointment
    let width: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color.opacity(0.85))
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
    }
}
