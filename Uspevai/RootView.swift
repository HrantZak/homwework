import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            TodayView().tabItem { Label("Сегодня", systemImage: "sparkles") }.tag(0)
            ScheduleView().tabItem { Label("Расписание", systemImage: "calendar") }.tag(1)
            GradebookView().tabItem { Label("Журнал", systemImage: "tablecells") }.tag(2)
            HomeworkView().tabItem { Label("Задания", systemImage: "checkmark.circle") }.tag(3)
            TrackerView().tabItem { Label("Прогресс", systemImage: "chart.bar.fill") }.tag(4)
        }.tint(AppTheme.violet)
         .task { await store.requestNotifications() }
    }
}
