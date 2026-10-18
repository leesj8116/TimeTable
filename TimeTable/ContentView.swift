import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAppointments: [Appointment]
    @Query private var allDogs: [Dog]

    @Environment(AppRouter.self) private var router
    @State private var selectedTab: AppTab = .timetable

    enum AppTab: Hashable {
        case timetable, members, waiting
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("시간표", systemImage: "calendar", value: .timetable) {
                WeeklyTimetableView()
            }

            Tab("회원", systemImage: "pawprint", value: .members) {
                DogListView()
            }

            Tab("대기", systemImage: "clock.badge.questionmark", value: .waiting) {
                WaitingMemoView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: router.pendingAction, initial: true) {
            // 액션 버튼·단축어 요청은 모두 시간표 탭에서 처리한다
            if router.pendingAction != nil {
                selectedTab = .timetable
            }
        }
        .onAppear {
            #if DEBUG
            ScreenshotSeedData.seedIfNeeded(modelContext: modelContext)
            #endif
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
        .environment(HolidayStore())
        .environment(AppRouter.shared)
}
