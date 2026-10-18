//
//  TimeTableApp.swift
//  TimeTable
//
//  Created by 이승주 on 5/5/26.
//

import SwiftUI
import SwiftData

@main
struct TimeTableApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Appointment.self,
            Dog.self,
            DayOff.self,
            ExtraWorkDay.self,
        ])
        // 스크린샷 시드 모드에서는 인메모리 스토어를 사용해 실제 데이터를 보호한다
        #if DEBUG
        let isStoredInMemoryOnly = CommandLine.arguments.contains(ScreenshotSeedData.launchArgument)
        #else
        let isStoredInMemoryOnly = false
        #endif
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var holidayStore = HolidayStore()
    @State private var router = AppRouter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(holidayStore)
                .environment(router)
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
