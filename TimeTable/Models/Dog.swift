import Foundation
import SwiftData

@Model
final class Dog {
    var id: UUID
    var name: String
    var latestDogName: String = ""
    var breedMemo: String
    var phoneNumbers: [String]
    var createdAt: Date

    init(
        name: String,
        latestDogName: String = "",
        breedMemo: String = "",
        phoneNumbers: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.name = name
        self.latestDogName = latestDogName
        self.breedMemo = breedMemo
        self.phoneNumbers = phoneNumbers
        self.createdAt = createdAt
    }

    var primaryPhoneNumber: String? {
        phoneNumbers.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func matches(_ query: String) -> Bool {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return true }

        if name.lowercased().contains(keyword) { return true }
        if latestDogName.lowercased().contains(keyword) { return true }
        if breedMemo.lowercased().contains(keyword) { return true }
        return phoneNumbers.contains { $0.lowercased().contains(keyword) }
    }
}
