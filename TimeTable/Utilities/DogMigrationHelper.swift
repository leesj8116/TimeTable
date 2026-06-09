import Foundation
import SwiftData

enum DogMigrationHelper {

    // Phase 1: 링크 없는 예약을 Dog 레코드와 연결
    static func backfillDogs(for appointments: [Appointment], existingDogs: [Dog], modelContext: ModelContext) {
        var dogsByName = Dictionary(grouping: existingDogs, by: { normalized($0.name) })
            .compactMapValues { $0.first }
        var didChange = false

        for appointment in appointments {
            guard appointment.dog == nil else { continue }
            let legacyName = appointment.dogName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !legacyName.isEmpty else { continue }

            let key = normalized(legacyName)
            let dog: Dog
            if let existingDog = dogsByName[key] {
                dog = existingDog
            } else {
                dog = Dog(name: legacyName)
                modelContext.insert(dog)
                dogsByName[key] = dog
            }

            appointment.dog = dog
            didChange = true
        }

        if didChange {
            try? modelContext.save()
        }
    }

    // Phase 2: Dog.name을 전화코드 전용으로, Appointment.dogName을 이름 전용으로 분리
    static func migrateToPhoneCodeKeys(
        for dogs: [Dog],
        appointments: [Appointment],
        modelContext: ModelContext
    ) {
        var didChange = false

        // 코드 패턴({이름}{4자리숫자})이 있는 Dog를 코드 기준으로 그룹화
        var canonicalByCode: [String: Dog] = [:]
        var toDelete: [Dog] = []

        for dog in dogs {
            guard let (extractedName, code) = splitNameCode(dog.name) else {
                // 패턴 없음 - latestDogName만 초기화
                if dog.latestDogName.isEmpty {
                    dog.latestDogName = dog.name
                    didChange = true
                }
                continue
            }

            if let canonical = canonicalByCode[code] {
                // 같은 코드의 Dog가 이미 있으면 중복 처리
                toDelete.append(dog)
                // 중복 Dog에 연결된 예약을 canonical로 재연결
                for appt in appointments where appt.dog?.id == dog.id {
                    appt.dog = canonical
                    didChange = true
                }
            } else {
                dog.name = code
                if dog.latestDogName.isEmpty {
                    dog.latestDogName = extractedName
                }
                canonicalByCode[code] = dog
                didChange = true
            }
        }

        for dog in toDelete {
            modelContext.delete(dog)
            didChange = true
        }

        // 예약의 dogName에서 코드 접미사 제거
        for appointment in appointments {
            if let (dogName, _) = splitNameCode(appointment.dogName) {
                appointment.dogName = dogName
                didChange = true
            }
            // canonical Dog의 latestDogName을 가장 최근 예약 이름으로 갱신
            if let dog = appointment.dog, !appointment.dogName.isEmpty {
                dog.latestDogName = appointment.dogName
                didChange = true
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }

    // "{이름}{4자리숫자}" 패턴을 (이름, 코드)로 분리. 패턴 불일치 시 nil 반환
    static func splitNameCode(_ value: String) -> (dogName: String, phoneCode: String)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5,
              String(trimmed.suffix(4)).allSatisfy({ $0.isNumber }) else { return nil }
        return (String(trimmed.dropLast(4)), String(trimmed.suffix(4)))
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
