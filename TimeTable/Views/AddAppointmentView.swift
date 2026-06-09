import SwiftUI
import SwiftData

struct AddAppointmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allAppointments: [Appointment]
    @Query private var allDogs: [Dog]
    @Query private var allDayOffs: [DayOff]

    let viewModel: TimetableViewModel

    @State private var dogName = ""
    @State private var selectedDog: Dog?
    @State private var serviceType: ServiceType = .fullGrooming
    @State private var startTime: Date
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var durationAdjustment = 0
    @State private var isTwoDogs: Bool = false
    @State private var memo: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isDogNameFocused: Bool

    init(defaultDate: Date? = nil, viewModel: TimetableViewModel) {
        self.viewModel = viewModel
        let initial = defaultDate ?? AddAppointmentView.defaultStartTime(viewModel: viewModel)
        _startTime = State(initialValue: initial)
        let cal = Calendar.current
        _startHour = State(initialValue: cal.component(.hour, from: initial))
        let minute = cal.component(.minute, from: initial)
        _startMinute = State(initialValue: minute >= 30 ? 30 : 0)
    }

    private var durationMinutes: Int {
        (serviceType.baseDuration + durationAdjustment) * (isTwoDogs ? 2 : 1)
    }

    private var trimmedDogName: String {
        dogName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        parsedInput(trimmedDogName).phoneCode != nil
    }

    private var suggestedDogs: [Dog] {
        guard !trimmedDogName.isEmpty else { return [] }
        let parsed = parsedInput(trimmedDogName)
        let searchQuery = parsed.phoneCode ?? trimmedDogName

        var matched = allDogs
            .filter { $0.matches(searchQuery) && $0.id != selectedDog?.id }

        if parsed.phoneCode == nil {
            var seen = Set(matched.map { $0.id })
            if let sid = selectedDog?.id { seen.insert(sid) }
            for appt in allAppointments {
                guard let dog = appt.dog, !seen.contains(dog.id) else { continue }
                if appt.dogName.localizedStandardContains(searchQuery) {
                    matched.append(dog)
                    seen.insert(dog.id)
                }
            }
        }

        return matched
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("강아지 정보") {
                    TextField("강아지 이름 (예: 뽀삐1234)", text: $dogName)
                        .autocorrectionDisabled()
                        .focused($isDogNameFocused)
                        .frame(maxWidth: .infinity)
                        .onChange(of: dogName) {
                            let parsed = parsedInput(trimmedDogName)
                            if selectedDog?.name != parsed.phoneCode {
                                selectedDog = nil
                            }
                        }
                    if !trimmedDogName.isEmpty && !isNameValid {
                        Text("끝 4자리를 전화번호로 입력해주세요 (예: 뽀삐1234)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let selectedDog {
                        HStack(alignment: .top) {
                            DogSummaryRow(dog: selectedDog)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    } else if !suggestedDogs.isEmpty {
                        ForEach(suggestedDogs) { dog in
                            Button {
                                selectDog(dog)
                            } label: {
                                HStack {
                                    DogSummaryRow(dog: dog)
                                    Spacer()
                                    Text("선택")
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
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
                    .onChange(of: startHour) { updateStartTime() }
                    .onChange(of: startMinute) { updateStartTime() }
                }
            }
            .navigationTitle("예약 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!isNameValid)
                }
            }
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

    private func selectDog(_ dog: Dog) {
        selectedDog = dog
        dogName = dog.latestDogName + dog.name
    }

    private func parsedInput(_ input: String) -> (dogName: String, phoneCode: String?) {
        guard let (name, code) = DogMigrationHelper.splitNameCode(input) else {
            return (input, nil)
        }
        return (name, code)
    }

    private func autoRegisterDogIfNeeded(input: String) -> Dog? {
        let parsed = parsedInput(input)
        guard let phoneCode = parsed.phoneCode else { return nil }
        if let existing = allDogs.first(where: { $0.name == phoneCode && $0.latestDogName == parsed.dogName }) {
            return existing
        }
        let newDog = Dog(name: phoneCode, latestDogName: parsed.dogName)
        modelContext.insert(newDog)
        return newDog
    }

    private func save() {
        guard !trimmedDogName.isEmpty else { return }

        let snapped = snapToHalfHour(startTime)

        guard viewModel.canBook(startTime: snapped, durationMinutes: durationMinutes, existing: allAppointments, dayOffs: allDayOffs) else {
            errorMessage = bookingErrorMessage(for: snapped)
            showError = true
            return
        }

        let parsed = parsedInput(trimmedDogName)
        let dogToLink: Dog?
        if let selected = selectedDog {
            dogToLink = selected
        } else {
            dogToLink = autoRegisterDogIfNeeded(input: trimmedDogName)
        }

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
                comps.hour = startHour
                comps.minute = startMinute
                comps.second = 0
                startTime = cal.date(from: comps) ?? newDate
            }
        )
    }

    private func updateStartTime() {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: startTime)
        comps.hour = startHour
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
