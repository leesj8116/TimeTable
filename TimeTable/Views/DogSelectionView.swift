import SwiftData
import SwiftUI

struct DogSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var dogs: [Dog]

    let selectedDog: Dog?
    let allowsAdding: Bool
    let onSelect: (Dog) -> Void

    @State private var searchText = ""
    @State private var showNewDogSheet = false

    private var filteredDogs: [Dog] {
        dogs
            .filter { $0.matches(searchText) }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredDogs.isEmpty {
                    ContentUnavailableView(
                        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "등록된 강아지가 없습니다" : "검색 결과가 없습니다",
                        systemImage: "pawprint",
                        description: Text(allowsAdding ? "우측 상단의 강아지 추가 버튼으로 신규 등록할 수 있습니다." : "예약 추가 화면에서 신규 강아지를 등록할 수 있습니다.")
                    )
                } else {
                    ForEach(filteredDogs) { dog in
                        Button {
                            onSelect(dog)
                            dismiss()
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
            }
            .navigationTitle("강아지 선택")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "이름 또는 전화번호 검색")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                if allowsAdding {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("강아지 추가") {
                            showNewDogSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewDogSheet) {
                NewDogRegistrationView { dog in
                    onSelect(dog)
                    dismiss()
                }
            }
        }
    }
}
