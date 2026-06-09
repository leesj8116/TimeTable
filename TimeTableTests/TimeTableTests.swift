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

    @Test func appointmentUsesLinkedDogNameForDisplay() async throws {
        let dog = Dog(name: "초코")
        let appointment = Appointment(
            dogName: "이전이름",
            dog: dog,
            serviceType: .bath,
            startTime: Date()
        )

        #expect(appointment.displayDogName == "초코")
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
}
