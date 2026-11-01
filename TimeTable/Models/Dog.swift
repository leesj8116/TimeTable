import Foundation
import SwiftData

enum DogBreed: String, CaseIterable, Identifiable {
    case maltese = "말티즈"
    case bichon = "비숑"
    case poodle = "푸들"
    case shihTzu = "시츄"
    case chihuahua = "치와와"
    case other = "기타"

    var id: String { rawValue }
}

@Model
final class Dog {
    var id: UUID
    var name: String
    var latestDogName: String = ""
    // 빈 문자열은 견종 선택 없음을 뜻한다
    var breed: String = ""
    // 기존 저장소와의 호환을 위해 이름을 유지하며, 견종 분리 이후에는 메모만 담는다
    var breedMemo: String
    var phoneNumbers: [String]
    var createdAt: Date

    init(
        name: String,
        latestDogName: String = "",
        breed: DogBreed? = nil,
        breedMemo: String = "",
        phoneNumbers: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.name = name
        self.latestDogName = latestDogName
        self.breed = breed?.rawValue ?? ""
        self.breedMemo = breedMemo
        self.phoneNumbers = phoneNumbers
        self.createdAt = createdAt
    }

    var dogBreed: DogBreed? {
        get { DogBreed(rawValue: breed) }
        set { breed = newValue?.rawValue ?? "" }
    }

    var primaryPhoneNumber: String? {
        phoneNumbers.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func matches(_ query: String) -> Bool {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return true }

        if name.lowercased().contains(keyword) { return true }
        if latestDogName.lowercased().contains(keyword) { return true }
        if breed.lowercased().contains(keyword) { return true }
        if breedMemo.lowercased().contains(keyword) { return true }
        return phoneNumbers.contains { $0.lowercased().contains(keyword) }
    }
}
