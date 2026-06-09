import SwiftUI
import SwiftData

struct EditAppointmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allAppointments: [Appointment]
    @Query private var allDayOffs: [DayOff]

    let appointment: Appointment
    let viewModel: TimetableViewModel

    @State private var selectedDog: Dog?
    @State private var serviceType: ServiceType
    @State private var startTime: Date
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var durationAdjustment: Int
    @State private var isTwoDogs: Bool
    @State private var memo: String
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDogSelectionSheet = false

    init(appointment: Appointment, viewModel: TimetableViewModel) {
        self.appointment = appointment
        self.viewModel   = viewModel

        let twoDogs = appointment.isTwoDogs
        let perDog  = appointment.durationMinutes / (twoDogs ? 2 : 1)

        _selectedDog        = State(initialValue: appointment.dog)
        _serviceType        = State(initialValue: appointment.serviceType)
        _startTime          = State(initialValue: appointment.startTime)
        _durationAdjustment = State(initialValue: perDog - appointment.serviceType.baseDuration)
        _isTwoDogs          = State(initialValue: twoDogs)
        _memo               = State(initialValue: appointment.memo)

        let cal = Calendar.current
        _startHour   = State(initialValue: cal.component(.hour, from: appointment.startTime))
        let rawMin   = cal.component(.minute, from: appointment.startTime)
        _startMinute = State(initialValue: rawMin >= 30 ? 30 : 0)
    }

    private var durationMinutes: Int {
        (serviceType.baseDuration + durationAdjustment) * (isTwoDogs ? 2 : 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("강아지 정보") {
                    if let selectedDog {
                        DogSummaryRow(dog: selectedDog)
                    } else {
                        Text(appointment.displayDogName)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showDogSelectionSheet = true
                    } label: {
                        Label(selectedDog == nil ? "강아지 선택" : "다른 강아지 선택", systemImage: "pawprint")
                    }
                }

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

                Section("예약 시간") {
                    DatePicker(
                        "날짜",
                        selection: dateBinding,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))

                    HStack {
                        Text("시작 시간")
                        Spacer()
                        Picker("시", selection: $startHour) {
                            ForEach(TimeSlotHelper.workStartHour..<TimeSlotHelper.workEndHour, id: \.self) { h in
                                Text("\(h > 12 ? h - 12 : h)시").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 120)
                        .clipped()

                        Picker("분", selection: $startMinute) {
                            Text("00분").tag(0)
                            Text("30분").tag(30)
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 120)
                        .clipped()
                    }
                    .onChange(of: startHour)   { updateStartTime() }
                    .onChange(of: startMinute) { updateStartTime() }
                }

                Section {
                    Button("예약 삭제", role: .destructive) {
                        delete()
                    }
                }
            }
            .navigationTitle("예약 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(selectedDog == nil)
                }
            }
            .alert("예약 불가", isPresented: $showError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showDogSelectionSheet) {
                DogSelectionView(selectedDog: selectedDog, allowsAdding: false) { dog in
                    selectedDog = dog
                }
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
        guard let dog = selectedDog else { return }

        let snapped = snapToHalfHour(startTime)

        guard viewModel.canBook(
            startTime: snapped,
            durationMinutes: durationMinutes,
            excluding: appointment.id,
            existing: allAppointments,
            dayOffs: allDayOffs
        ) else {
            errorMessage = bookingErrorMessage(for: snapped)
            showError = true
            return
        }

        appointment.dogName         = dog.latestDogName.isEmpty ? dog.name : dog.latestDogName
        appointment.dog             = dog
        appointment.serviceType     = serviceType
        appointment.startTime       = snapped
        appointment.durationMinutes = durationMinutes
        appointment.isTwoDogs       = isTwoDogs
        appointment.memo            = memo
        dismiss()
    }

    private func delete() {
        modelContext.delete(appointment)
        dismiss()
    }

    private func bookingErrorMessage(for date: Date) -> String {
        let cal = Calendar.current
        if allDayOffs.contains(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            return "휴무일에는 예약할 수 없습니다."
        }
        if !TimeSlotHelper.isWorkDay(date) {
            return "화요일~토요일만 예약 가능합니다."
        }
        let startMin = TimeSlotHelper.timeOfDayMinutes(for: date)
        let endMin   = startMin + durationMinutes
        if startMin < TimeSlotHelper.workStartHour * 60 || endMin > TimeSlotHelper.workEndHour * 60 {
            return "영업 시간(10:00~20:00) 내에서만 예약 가능합니다."
        }
        return "해당 시간에 이미 예약이 있습니다."
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { startTime },
            set: { newDate in
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: newDate)
                comps.hour   = startHour
                comps.minute = startMinute
                comps.second = 0
                startTime = cal.date(from: comps) ?? newDate
            }
        )
    }

    private func updateStartTime() {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: startTime)
        comps.hour   = startHour
        comps.minute = startMinute
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
