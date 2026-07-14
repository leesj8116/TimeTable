import Foundation
import SwiftData

#if DEBUG
/// README 스크린샷 촬영용 샘플 데이터 시더.
/// `--seed-screenshot-data` 런치 인자가 있을 때만 동작하며,
/// TimeTableApp이 같은 인자를 감지해 인메모리 스토어를 사용하므로 실제 데이터에는 영향이 없다.
enum ScreenshotSeedData {
    static let launchArgument = "--seed-screenshot-data"

    static func seedIfNeeded(modelContext: ModelContext) {
        guard CommandLine.arguments.contains(launchArgument) else { return }

        let existingCount = (try? modelContext.fetchCount(FetchDescriptor<Appointment>())) ?? 0
        guard existingCount == 0 else { return }

        // 현재 표시되는 주간(화~토)에 맞춰 날짜 계산
        let days = TimetableViewModel().weekDays()
        guard days.count == 5 else { return }

        // 영업시간(10:00~20:00) 내에서 점심시간(12:30~13:00)과 서로 겹치지 않게 배치
        let samples: [(name: String, code: String, breed: String,
                       service: ServiceType, dayIndex: Int, hour: Int, minute: Int, memo: String)] = [
            ("뽀삐", "1234", "말티즈",       .fullGrooming,     0, 10, 0,  ""),
            ("초코", "5678", "푸들",         .scissorCut,       0, 14, 0,  ""),
            ("콩이", "2468", "포메라니안",   .bath,             1, 11, 0,  ""),
            ("두부", "1357", "시츄",         .sanitary,         1, 15, 0,  ""),
            ("몽이", "9012", "말티푸",       .partialFace,      2, 10, 30, ""),
            ("보리", "3456", "비숑",         .scissorCutBichon, 3, 13, 0,  ""),
            ("해피", "7890", "골든리트리버", .bath,             4, 10, 0,  "첫 방문"),
        ]

        let calendar = Calendar.current
        for sample in samples {
            guard let startTime = calendar.date(
                bySettingHour: sample.hour,
                minute: sample.minute,
                second: 0,
                of: days[sample.dayIndex]
            ) else { continue }

            let dog = Dog(name: sample.code, latestDogName: sample.name, breedMemo: sample.breed)
            modelContext.insert(dog)

            let appointment = Appointment(
                dogName: sample.name,
                dog: dog,
                serviceType: sample.service,
                startTime: startTime,
                memo: sample.memo
            )
            modelContext.insert(appointment)
        }
    }
}
#endif
