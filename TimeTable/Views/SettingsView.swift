import SwiftUI

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("showHolidays") private var showHolidays = true

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("화면 테마") {
                    Picker("테마", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Toggle("공휴일 표시", isOn: $showHolidays)
                } header: {
                    Text("시간표")
                } footer: {
                    Text("기기의 대한민국 공휴일 캘린더를 읽어와 시간표에 표시합니다.")
                }

                Section("예약") {
                    NavigationLink("서비스 기본 소요시간") {
                        ServiceDurationSettingsView()
                    }
                    NavigationLink("예약 통계") {
                        StatisticsView()
                    }
                }

                Section("앱 정보") {
                    LabeledContent("버전", value: appVersion)
                }
            }
            .navigationTitle("설정")
        }
    }
}

#Preview {
    SettingsView()
}
