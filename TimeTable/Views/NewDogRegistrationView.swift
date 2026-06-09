import SwiftData
import SwiftUI

struct NewDogRegistrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onComplete: (Dog) -> Void

    @State private var name = ""
    @State private var breedMemo = ""
    @State private var phoneNumbers = [""]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("강아지 이름 (예: 뽀삐1234)", text: $name)
                        .autocorrectionDisabled()
                    TextField("견종 또는 특징 메모", text: $breedMemo, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("휴대전화번호") {
                    ForEach(phoneNumbers.indices, id: \.self) { index in
                        HStack {
                            PhoneNumberInputRow(phoneNumber: $phoneNumbers[index])
                            if phoneNumbers.count > 1 {
                                Button(role: .destructive) {
                                    phoneNumbers.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                            }
                        }
                    }

                    Button {
                        phoneNumbers.append("")
                    } label: {
                        Label("번호 추가", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("강아지 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let phones = uniquePhoneNumbers(from: phoneNumbers)
        let (dogName, phoneCode) = DogMigrationHelper.splitNameCode(trimmedName) ?? (trimmedName, nil)
        let dog = Dog(
            name: phoneCode ?? trimmedName,
            latestDogName: phoneCode != nil ? dogName : "",
            breedMemo: breedMemo.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumbers: phones
        )

        modelContext.insert(dog)
        try? modelContext.save()

        onComplete(dog)
        dismiss()
    }

    private func uniquePhoneNumbers(from values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }

        return result
    }
}
