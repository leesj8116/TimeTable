import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAppointments: [Appointment]
    @Query private var allDogs: [Dog]

    var body: some View {
        TabView {
            WeeklyTimetableView()
                .tabItem {
                    Label("시간표", systemImage: "calendar")
                }

            DogListView()
                .tabItem {
                    Label("회원", systemImage: "pawprint")
                }

            WaitingMemoView()
                .tabItem {
                    Label("대기", systemImage: "clock.badge.questionmark")
                }
        }
        .onAppear {
            DogMigrationHelper.migrateToPhoneCodeKeys(
                for: allDogs,
                appointments: allAppointments,
                modelContext: modelContext
            )
            DogMigrationHelper.backfillDogs(
                for: allAppointments,
                existingDogs: allDogs,
                modelContext: modelContext
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Appointment.self, Dog.self], inMemory: true)
}
