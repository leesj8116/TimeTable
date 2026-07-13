import SwiftUI

struct ServiceDurationSettingsView: View {
    var body: some View {
        Form {
            Section {
                ForEach(ServiceType.allCases, id: \.self) { service in
                    ServiceDurationRow(service: service)
                }
            } footer: {
                Text("예약 등록 시 자동으로 계산되는 기본 소요시간입니다. 이미 등록된 예약에는 영향을 주지 않습니다.")
            }

            Section {
                Button("기본값으로 재설정", role: .destructive) {
                    resetServiceDurations()
                }
            }
        }
        .navigationTitle("서비스 기본 소요시간")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resetServiceDurations() {
        for service in ServiceType.allCases {
            UserDefaults.standard.removeObject(forKey: ServiceType.durationStorageKey(for: service))
        }
    }
}

private struct ServiceDurationRow: View {
    let service: ServiceType
    @AppStorage private var duration: Int

    private static let stepMinutes = 10
    private static let range = 10...480

    init(service: ServiceType) {
        self.service = service
        _duration = AppStorage(
            wrappedValue: service.baseDuration,
            ServiceType.durationStorageKey(for: service)
        )
    }

    var body: some View {
        Stepper(value: $duration, in: Self.range, step: Self.stepMinutes) {
            HStack {
                Text(service.rawValue)
                Spacer()
                Text(formatted(minutes: duration))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatted(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        switch (hours, mins) {
        case (0, _): return "\(mins)분"
        case (_, 0): return "\(hours)시간"
        default: return "\(hours)시간 \(mins)분"
        }
    }
}

#Preview {
    NavigationStack {
        ServiceDurationSettingsView()
    }
}
