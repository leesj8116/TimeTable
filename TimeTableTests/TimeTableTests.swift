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

    @Test func dogBreedDefaultsToNoneAndIsSearchable() async throws {
        let dog = Dog(name: "1234")
        #expect(dog.dogBreed == nil)
        #expect(!dog.matches("비숑"))

        dog.dogBreed = .bichon
        #expect(dog.breed == "비숑")
        #expect(dog.matches("비숑"))

        dog.dogBreed = nil
        #expect(dog.breed.isEmpty)
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

    @Test func weekDaysIncludesMondayOnlyWhenRequested() async throws {
        let viewModel = TimetableViewModel()
        let weekStart = TimetableViewModel.startOfWeek(for: Date())
        let cal = Calendar.current

        let regular = viewModel.weekDays(for: weekStart)
        #expect(regular.count == 5)
        #expect(cal.component(.weekday, from: regular[0]) == 3) // 화

        let withMonday = viewModel.weekDays(for: weekStart, includeMonday: true)
        #expect(withMonday.count == 6)
        #expect(cal.component(.weekday, from: withMonday[0]) == 2) // 월
        #expect(cal.isDate(withMonday[0], inSameDayAs: viewModel.monday(for: weekStart)))
    }

    // 월요일은 기본적으로 예약 불가이고, 추가 근무일로 지정하면 예약 가능하다
    @Test func canBookMondayOnlyWhenExtraWorkDay() async throws {
        let viewModel = TimetableViewModel()
        let monday = viewModel.monday(for: TimetableViewModel.startOfWeek(for: Date()))
        let start = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: monday)!

        #expect(!viewModel.canBook(startTime: start, durationMinutes: 60))
        #expect(viewModel.canBook(
            startTime: start,
            durationMinutes: 60,
            extraWorkDays: [ExtraWorkDay(date: monday)]
        ))
    }

    // 종료가 20:00을 넘으면 거부하고, 자정을 넘겨 이른 시각으로 보이는 예약도 거부한다
    @Test func canBookRejectsAppointmentsEndingAfterClosing() async throws {
        let viewModel = TimetableViewModel()

        #expect(viewModel.canBook(startTime: tuesday(hour: 19), durationMinutes: 60))
        #expect(!viewModel.canBook(startTime: tuesday(hour: 19), durationMinutes: 90))
        #expect(!viewModel.canBook(startTime: tuesday(hour: 19, minute: 30), durationMinutes: 300))
    }

    // 시작 시각은 영업시간 안에서 30분 단위로만 고른다
    @Test func startSlotsCoverBusinessHoursInHalfHours() async throws {
        let slots = TimeSlotHelper.startSlots

        #expect(slots.count == 20)
        #expect(TimeSlotHelper.timeLabel(forMinutes: slots[0]) == "10:00")
        #expect(TimeSlotHelper.timeLabel(forMinutes: slots[1]) == "10:30")
        #expect(TimeSlotHelper.timeLabel(forMinutes: slots[19]) == "19:30")
    }

    @Test func overlappingAppointmentsFindsOnlyTimeConflicts() async throws {
        let viewModel = TimetableViewModel()
        let long = appointment(.fullGrooming, start: tuesday(hour: 10)) // 10:00~12:00
        let later = appointment(.bath, start: tuesday(hour: 11))        // 11:00~12:00
        let nextDay = appointment(.bath, start: tuesday(hour: 10, dayOffset: 1))
        let existing = [later, long, nextDay]

        // 시작 시각 순으로 돌려준다
        let overlapping = viewModel.overlappingAppointments(
            startTime: tuesday(hour: 11, minute: 30),
            durationMinutes: 30,
            existing: existing
        )
        #expect(overlapping.map(\.id) == [long.id, later.id])

        // 앞 예약이 끝나는 시각에 시작하면 겹치지 않는다
        #expect(viewModel.overlappingAppointments(
            startTime: tuesday(hour: 12),
            durationMinutes: 30,
            existing: existing
        ).isEmpty)

        // 수정 중인 예약 자신은 제외한다
        let excludingSelf = viewModel.overlappingAppointments(
            startTime: tuesday(hour: 10),
            durationMinutes: 30,
            excluding: long.id,
            existing: existing
        )
        #expect(excludingSelf.isEmpty)
    }

    @Test func groupsKeepSeparatedAppointmentsAsOwnCards() async throws {
        let first = appointment(.bath, start: tuesday(hour: 10))  // 10:00~11:00
        let second = appointment(.bath, start: tuesday(hour: 11)) // 맞닿음
        let otherDay = appointment(.bath, start: tuesday(hour: 10, dayOffset: 1))

        let groups = TimeSlotHelper.groups(for: [first, second, otherDay])

        #expect(groups.count == 3)
        #expect(groups.allSatisfy { $0.children.isEmpty })
    }

    // 긴 예약이 카드가 되고 겹치는 예약은 시작 시각 순으로 그 아래에 들어간다
    @Test func groupsNestShorterAppointmentsInLongest() async throws {
        let long = appointment(.fullGrooming, start: tuesday(hour: 10)) // 10:00~12:00
        let firstShort = appointment(.sanitary, start: tuesday(hour: 10, minute: 30))
        let secondShort = appointment(.sanitary, start: tuesday(hour: 11))
        let afterGroup = appointment(.bath, start: tuesday(hour: 12))

        let groups = TimeSlotHelper.groups(for: [secondShort, afterGroup, firstShort, long])

        #expect(groups.count == 2)
        let host = groups.first { $0.host.id == long.id }
        #expect(host?.children.map(\.id) == [firstShort.id, secondShort.id])
        #expect(host?.members.count == 3)
        #expect(groups.first { $0.host.id == afterGroup.id }?.children.isEmpty == true)
    }

    // 같은 시각에 시작하면 입력 순서와 상관없이 긴 예약이 카드가 된다
    @Test func groupsPickLongerAppointmentAsHost() async throws {
        let short = appointment(.sanitary, start: tuesday(hour: 10))
        let long = appointment(.fullGrooming, start: tuesday(hour: 10))

        let groups = TimeSlotHelper.groups(for: [short, long])

        #expect(groups.map(\.host.id) == [long.id])
        #expect(groups.first?.children.map(\.id) == [short.id])
    }

    @Test func groupsPickEarlierAppointmentWhenLengthsMatch() async throws {
        let later = appointment(.bath, start: tuesday(hour: 10, minute: 30))
        let earlier = appointment(.bath, start: tuesday(hour: 10))

        let groups = TimeSlotHelper.groups(for: [later, earlier])

        #expect(groups.map(\.host.id) == [earlier.id])
    }

    // 하위 예약하고만 겹치는 예약은 따로 카드가 되어 카드끼리 겹치지 않는다
    @Test func groupsDoNotChainThroughChildren() async throws {
        let long = appointment(.fullGrooming, start: tuesday(hour: 10))             // 10:00~12:00
        let bridge = appointment(.bath, start: tuesday(hour: 11, minute: 30))       // 11:30~12:30
        let afterLong = appointment(.bath, start: tuesday(hour: 12))                // 12:00~13:00

        let groups = TimeSlotHelper.groups(for: [long, bridge, afterLong])

        #expect(groups.count == 2)
        #expect(groups.first { $0.host.id == long.id }?.children.map(\.id) == [bridge.id])
        #expect(groups.first { $0.host.id == afterLong.id }?.children.isEmpty == true)
    }

    // 0분 예약도 카드 높이만큼 화면을 차지하므로 바로 뒤 예약의 하위로 넣는다
    @Test func groupsUseCardHeightForVeryShortAppointments() async throws {
        let zeroMinutes = appointment(.sanitary, start: tuesday(hour: 10), adjustment: -30)
        let next = appointment(.bath, start: tuesday(hour: 10, minute: 10))

        let groups = TimeSlotHelper.groups(for: [zeroMinutes, next])

        #expect(groups.map(\.host.id) == [next.id])
        #expect(groups.first?.children.map(\.id) == [zeroMinutes.id])
    }

    // 방문 기록에서 예약을 선택하면 그 예약이 속한 주(ISO 주 시작 = 월요일)로 이동한다
    @Test func goToWeekMovesToWeekContainingDate() async throws {
        let cal = Calendar.current
        let viewModel = TimetableViewModel()
        let saturday = cal.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 14))!

        viewModel.goToWeek(containing: saturday)

        let expectedMonday = cal.date(from: DateComponents(year: 2025, month: 3, day: 10))!
        #expect(cal.isDate(viewModel.currentWeekStart, inSameDayAs: expectedMonday))
        #expect(viewModel.weekDays().contains { cal.isDate($0, inSameDayAs: saturday) })
    }

    // MARK: - Helpers

    /// 2025-03-11은 화요일이다
    private func tuesday(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 11 + dayOffset, hour: hour, minute: minute))!
    }

    private func appointment(_ service: ServiceType, start: Date, adjustment: Int = 0) -> Appointment {
        Appointment(dogName: "초코", serviceType: service, startTime: start, durationAdjustment: adjustment)
    }
}
