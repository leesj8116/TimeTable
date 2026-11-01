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
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "이름 또는 전화번호 검색"
            )
        }
    }
}

struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allAppointments: [Appointment]
    @Bindable var dog: Dog
    // 전화번호 뒷자리는 비어 있으면 저장하지 않도록 따로 들고 있는다
    @State private var code: String
    @State private var showDeleteConfirmation = false

    init(dog: Dog) {
        _dog = Bindable(dog)
        _code = State(initialValue: dog.name)
    }

    private var visitAppointments: [Appointment] {
        allAppointments
            .filter { $0.dog?.id == dog.id }
            .sorted { $0.startTime > $1.startTime }
    }

    private var isCodeEmpty: Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("전화번호 뒷자리") {
                    TextField("뒷 4자리", text: $code)
                        .autocorrectionDisabled()
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("강아지 이름") {
                    TextField("이름", text: $dog.latestDogName)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                Picker("견종", selection: $dog.dogBreed) {
                    Text("선택 없음").tag(DogBreed?.none)
                    ForEach(DogBreed.allCases) { breed in
                        Text(breed.rawValue).tag(Optional(breed))
                    }
                }
            } header: {
                Text("기본 정보")
            } footer: {
                if isCodeEmpty {
                    Text("전화번호 뒷자리를 입력해야 변경 사항이 반영됩니다.")
                        .foregroundStyle(.red)
                }
            }

            Section("메모") {
                TextField("특징 메모", text: $dog.breedMemo, axis: .vertical)
                    .lineLimit(2...4)
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
        .onChange(of: code) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            dog.name = trimmed
        }
        .onDisappear {
            try? modelContext.save()
        }
        .toolbarOverflowMenu {
            Button("삭제", systemImage: "trash", role: .destructive) {
                showDeleteConfirmation = true
            }
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
