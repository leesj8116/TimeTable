import SwiftUI
import SwiftData

struct AddAppointmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false
    @Query private var allAppointments: [Appointment]
    @Query private var allDogs: [Dog]
    @Query private var allDayOffs: [DayOff]
    @Query private var allExtraWorkDays: [ExtraWorkDay]

    let viewModel: TimetableViewModel

    @State private var dogName = ""
    @State private var selectedDog: Dog?
    @State private var serviceType: ServiceType = .fullGrooming
    @State private var startTime: Date
    @State private var startMinutes: Int
    @State private var durationAdjustment = 0
    @State private var isTwoDogs: Bool = false
    @State private var memo: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

    private let initialStartTime: Date

    init(defaultDate: Date? = nil, viewModel: TimetableViewModel) {
        self.viewModel = viewModel
        let initial = defaultDate ?? AddAppointmentView.defaultStartTime(viewModel: viewModel)
        initialStartTime = initial
        _startTime = State(initialValue: initial)
        _startMinutes = State(initialValue: TimeSlotHelper.timeOfDayMinutes(for: initial) / 30 * 30)
    }

    private var durationMinutes: Int {
        (serviceType.baseDuration + durationAdjustment) * (isTwoDogs ? 2 : 1)
    }

    private var overlappingAppointments: [Appointment] {
        viewModel.overlappingAppointments(
            startTime: startTime,
            durationMinutes: durationMinutes,
            existing: allAppointments
        )
    }

    private var trimmedDogName: String {
        dogName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        !trimmedDogName.isEmpty
            || !memo.isEmpty
            || serviceType != .fullGrooming
            || durationAdjustment != 0
            || isTwoDogs
            || startTime != initialStartTime
    }

    private var isNameValid: Bool {
        DogMigrationHelper.splitNameCode(trimmedDogName) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                DogNameInputSection(
                    dogName: $dogName,
                    selectedDog: $selectedDog,
                    allDogs: allDogs,
                    allAppointments: allAppointments
                )

                Section("메모") {
                    TextField("메모 입력", text: $memo, axis: .vertical)
                        .lineLimit(1...)
                }

                Section("서비스") {
                    Picker("서비스 종류", selection: $serviceType) {
                        ForEach(ServiceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: serviceType) { durationAdjustment = 0 }

                    HStack {
                        Text("시간 조정")
                        Spacer()
                        Stepper(adjustmentLabel, value: $durationAdjustment, in: -30...60, step: 30)
                    }

                    HStack {
                        Text("소요 시간")
                        Spacer()
                        Text(durationLabel)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("한집 두마리", isOn: $isTwoDogs)
                }

                Section {
                    DatePicker(
                        "날짜",
                        selection: dateBinding,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))

                    StartTimePicker(selection: $startMinutes)
                        .onChange(of: startMinutes) { updateStartTime() }
                } header: {
                    Text("예약 시간")
                } footer: {
                    OverlapNoticeView(appointments: overlappingAppointments)
                }
            }
            .navigationTitle("예약 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", role: .cancel) {
                        if hasChanges {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", role: .confirm) { save() }
                        .disabled(!isNameValid)
                }
            }
            .confirmationDialog("변경 사항을 버릴까요?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("변경 사항 버리기", role: .destructive) { dismiss() }
                Button("계속 편집", role: .cancel) {}
            }
            .interactiveDismissDisabled(hasChanges)
            .alert("예약 불가", isPresented: $showError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var adjustmentLabel: String {
        switch durationAdjustment {
        case ..<0: return "\(durationAdjustment)분"
        case 1...: return "+\(durationAdjustment)분"
        default:   return "기본"
        }
    }

    private var durationLabel: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
    }

    private func save() {
        guard !trimmedDogName.isEmpty else { return }

        let snapped = snapToHalfHour(startTime)

        guard viewModel.canBook(startTime: snapped, durationMinutes: durationMinutes, dayOffs: allDayOffs, extraWorkDays: allExtraWorkDays) else {
            errorMessage = bookingErrorMessage(for: snapped)
            showError = true
            return
        }

        guard let parsed = DogMigrationHelper.splitNameCode(trimmedDogName) else { return }
        let dogToLink = selectedDog
            ?? DogMigrationHelper.findOrCreateDog(input: trimmedDogName, existingDogs: allDogs, modelContext: modelContext)

        let effectiveAdjustment = durationMinutes - serviceType.baseDuration
        let appt = Appointment(
            dogName: parsed.dogName,
            dog: dogToLink,
            serviceType: serviceType,
            startTime: snapped,
            durationAdjustment: effectiveAdjustment,
            memo: memo
        )
        appt.isTwoDogs = isTwoDogs
        modelContext.insert(appt)
        dismiss()
    }

    private func bookingErrorMessage(for date: Date) -> String {
        let cal = Calendar.current
        if allDayOffs.contains(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            return "휴무일에는 예약할 수 없습니다."
        }
        if !TimetableViewModel.isWorkDay(date, extraWorkDays: allExtraWorkDays) {
            return "화요일~토요일(또는 추가 근무일)만 예약 가능합니다."
        }
        return "영업 시간(10:00~20:00) 내에서만 예약 가능합니다."
    }

    private static func defaultStartTime(viewModel: TimetableViewModel) -> Date {
        let days = viewModel.weekDays()
        let cal  = Calendar.current
        let today = Date()

        let target = days.first(where: { cal.isDate($0, inSameDayAs: today) }) ?? days.first ?? today
        var comps  = cal.dateComponents([.year, .month, .day], from: target)
        comps.hour   = 10
        comps.minute = 0
        return cal.date(from: comps) ?? today
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { startTime },
            set: { newDate in
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: newDate)
                comps.hour = startMinutes / 60
                comps.minute = startMinutes % 60
                comps.second = 0
                startTime = cal.date(from: comps) ?? newDate
            }
        )
    }

    private func updateStartTime() {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: startTime)
        comps.hour = startMinutes / 60
        comps.minute = startMinutes % 60
        comps.second = 0
        startTime = cal.date(from: comps) ?? startTime
    }

    private func snapToHalfHour(_ date: Date) -> Date {
        let cal  = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.minute  = ((comps.minute ?? 0) / 30) * 30
        comps.second  = 0
        return cal.date(from: comps) ?? date
    }
}
