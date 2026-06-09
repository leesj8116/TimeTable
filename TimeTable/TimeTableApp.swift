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
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var holidayStore = HolidayStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(holidayStore)
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
