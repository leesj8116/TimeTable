import SwiftUI

/// 예약 추가/수정 화면에서 공용으로 쓰는 강아지 이름 입력 섹션.
/// "{이름}{전화 끝 4자리}" 형식 입력, 유효성 안내, 기존 회원 자동완성 추천을 제공한다.
struct DogNameInputSection: View {
    @Binding var dogName: String
    @Binding var selectedDog: Dog?
    let allDogs: [Dog]
    let allAppointments: [Appointment]

    private var trimmedDogName: String {
        dogName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        DogMigrationHelper.splitNameCode(trimmedDogName) != nil
    }

    private var suggestedDogs: [Dog] {
        guard !trimmedDogName.isEmpty else { return [] }
        let phoneCode = DogMigrationHelper.splitNameCode(trimmedDogName)?.phoneCode
        let searchQuery = phoneCode ?? trimmedDogName

        var matched = allDogs
            .filter { $0.matches(searchQuery) && $0.id != selectedDog?.id }

        if phoneCode == nil {
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
        Section("강아지 정보") {
            TextField("강아지 이름 (예: 뽀삐1234)", text: $dogName)
                .autocorrectionDisabled()
                .frame(maxWidth: .infinity)
                .onChange(of: dogName) {
                    let phoneCode = DogMigrationHelper.splitNameCode(trimmedDogName)?.phoneCode
                    if selectedDog?.name != phoneCode {
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
    }

    private func selectDog(_ dog: Dog) {
        selectedDog = dog
        dogName = dog.latestDogName + dog.name
    }
}
