import SwiftUI

struct DogPickerSection: View {
    let dogs: [Dog]
    @Binding var searchText: String
    @Binding var selectedDog: Dog?
    var allowsNewDog = false
    var onNewDog: () -> Void = {}

    private var filteredDogs: [Dog] {
        dogs
            .filter { $0.matches(searchText) }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        Section("강아지 정보") {
            if let selectedDog {
                DogSummaryRow(dog: selectedDog)
                Button("선택 해제") {
                    self.selectedDog = nil
                }
                .foregroundStyle(.secondary)
            }

            TextField("강아지 이름 또는 전화번호 검색", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if filteredDogs.isEmpty {
                Text("검색 결과가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredDogs) { dog in
                    Button {
                        selectedDog = dog
                        searchText = dog.latestDogName + dog.name
                    } label: {
                        HStack {
                            DogSummaryRow(dog: dog)
                            Spacer()
                            if selectedDog?.id == dog.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if allowsNewDog {
                Button {
                    onNewDog()
                } label: {
                    Label("신규 강아지 등록", systemImage: "plus.circle")
                }
            }
        }
    }
}

struct DogSummaryRow: View {
    let dog: Dog

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(dog.name)
                    .fontWeight(.bold)
                if !dog.latestDogName.isEmpty {
                    Text(dog.latestDogName)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            if !dog.breedMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(dog.breedMemo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let phone = dog.primaryPhoneNumber {
                Text(phone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
