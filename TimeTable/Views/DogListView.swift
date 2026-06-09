import SwiftData
import SwiftUI

struct DogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dogs: [Dog]
    @Query private var allAppointments: [Appointment]
    @State private var searchText = ""

    private var filteredDogs: [Dog] {
        dogs
            .filter { $0.matches(searchText) }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private func pastDogNames(for dog: Dog) -> [String] {
        var seen = Set<String>()
        return allAppointments
            .filter { $0.dog?.id == dog.id }
            .sorted { $0.startTime > $1.startTime }
            .compactMap { appt -> String? in
                let name = appt.dogName
                guard !name.isEmpty, name != dog.latestDogName, !seen.contains(name) else { return nil }
                seen.insert(name)
                return name
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredDogs.isEmpty {
                    ContentUnavailableView(
                        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "등록된 강아지가 없습니다" : "검색 결과가 없습니다",
                        systemImage: "pawprint",
                        description: Text("예약 추가 화면에서 신규 강아지를 등록할 수 있습니다.")
                    )
                } else {
                    ForEach(filteredDogs) { dog in
                        NavigationLink {
                            DogDetailView(dog: dog)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                DogSummaryRow(dog: dog)
                                let others = pastDogNames(for: dog)
                                if !others.isEmpty {
                                    Text(others.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(filteredDogs[index])
                        }
                    }
                }
            }
            .navigationTitle("회원")
            .searchable(text: $searchText, prompt: "이름 또는 전화번호 검색")
        }
    }
}

struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allAppointments: [Appointment]
    let dog: Dog
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    private var visitAppointments: [Appointment] {
        allAppointments
            .filter { $0.dog?.id == dog.id }
            .sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        Form {
            Section("기본 정보") {
                LabeledContent("전화번호 뒷자리", value: dog.name)
                if !dog.latestDogName.isEmpty {
                    LabeledContent("강아지 이름", value: dog.latestDogName)
                }
                if dog.breedMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("견종/메모", value: "-")
                } else {
                    LabeledContent("견종/메모", value: dog.breedMemo)
                }
            }

            Section("휴대전화번호") {
                if dog.phoneNumbers.isEmpty {
                    Text("등록된 번호가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dog.phoneNumbers, id: \.self) { phoneNumber in
                        Text(phoneNumber)
                    }
                }
            }

            Section("방문 기록") {
                LabeledContent("방문 횟수", value: "\(visitAppointments.count)회")
                ForEach(visitAppointments) { appt in
                    HStack {
                        Text(appt.startTime, format: .dateTime.year().month().day())
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                        Spacer()
                        if !appt.dogName.isEmpty {
                            Text(appt.dogName)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Text(appt.serviceType.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .navigationTitle(dog.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("수정") {
                    showEditSheet = true
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("삭제", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditDogView(dog: dog) { }
        }
        .confirmationDialog("강아지를 삭제하시겠어요?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                modelContext.delete(dog)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("기존 예약 내역은 유지됩니다.")
        }
    }
}
