import SwiftData
import SwiftUI

struct EditDogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var appointments: [Appointment]

    let dog: Dog
    let onComplete: () -> Void

    @State private var name: String
    @State private var breedMemo: String
    @State private var phoneNumbers: [String]

    init(dog: Dog, onComplete: @escaping () -> Void) {
        self.dog = dog
        self.onComplete = onComplete
        _name = State(initialValue: dog.name)
        _breedMemo = State(initialValue: dog.breedMemo)
        _phoneNumbers = State(initialValue: dog.phoneNumbers.isEmpty ? [""] : dog.phoneNumbers)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("전화번호 뒷 4자리", text: $name)
                        .autocorrectionDisabled()
                        .keyboardType(.numberPad)
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
            .navigationTitle("강아지 수정")
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

        dog.name = trimmedName
        dog.breedMemo = breedMemo.trimmingCharacters(in: .whitespacesAndNewlines)
        dog.phoneNumbers = phones

        try? modelContext.save()

        onComplete()
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
