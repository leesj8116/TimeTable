import Foundation
import SwiftData
import Testing
@testable import TimeTable

struct TimeTableTests {

    @Test func dogSearchMatchesNameBreedAndPhone() async throws {
        let dog = Dog(name: "콩이", breedMemo: "말티푸", phoneNumbers: ["010-1234-5678"])

        #expect(dog.matches("콩"))
        #expect(dog.matches("말티"))
        #expect(dog.matches("1234"))
        #expect(!dog.matches("푸들"))
    }

    // Dog.name은 전화코드 마이그레이션 이후 코드 저장용이고, 표시 이름은 Appointment.dogName이 담당한다
    @Test func appointmentDisplaysOwnDogNameAndLinkedDogCode() async throws {
        let dog = Dog(name: "1234", latestDogName: "초코")
        let appointment = Appointment(
            dogName: "초코",
            dog: dog,
            serviceType: .bath,
            startTime: Date()
        )

        #expect(appointment.displayDogName == "초코")
        #expect(appointment.dogNameParts.name == "초코")
        #expect(appointment.dogNameParts.code == "1234")
    }

    @MainActor
    @Test func legacyAppointmentsAreBackfilledIntoDogs() async throws {
        let container = try ModelContainer(
            for: Appointment.self, Dog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let appointment = Appointment(dogName: "보리", serviceType: .bath, startTime: Date())
        context.insert(appointment)

        DogMigrationHelper.backfillDogs(for: [appointment], existingDogs: [], modelContext: context)

        let dogs = try context.fetch(FetchDescriptor<Dog>())
        #expect(dogs.count == 1)
        #expect(dogs.first?.name == "보리")
        #expect(appointment.dog?.name == "보리")
    }

    @MainActor
    @Test func findOrCreateDogReusesExistingAndRegistersNew() async throws {
        let container = try ModelContainer(
            for: Dog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let existing = Dog(name: "1234", latestDogName: "초코")
        context.insert(existing)

        // 같은 코드+이름이면 기존 Dog 재사용
        let reused = DogMigrationHelper.findOrCreateDog(input: "초코1234", existingDogs: [existing], modelContext: context)
        #expect(reused?.id == existing.id)

        // 새 코드면 새 Dog 등록 (name=코드, latestDogName=이름)
        let created = DogMigrationHelper.findOrCreateDog(input: "뽀삐5678", existingDogs: [existing], modelContext: context)
        #expect(created?.name == "5678")
        #expect(created?.latestDogName == "뽀삐")
        let dogs = try context.fetch(FetchDescriptor<Dog>())
        #expect(dogs.count == 2)

        // 전화코드 패턴이 없으면 nil
        let invalid = DogMigrationHelper.findOrCreateDog(input: "초코", existingDogs: [existing], modelContext: context)
        #expect(invalid == nil)
    }
}
