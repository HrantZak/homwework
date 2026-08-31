import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            TodayView().tabItem { Label("Сегодня", systemImage: "sparkles") }.tag(0)
            ScheduleView().tabItem { Label("Расписание", systemImage: "calendar") }.tag(1)
            HomeworkView().tabItem { Label("Задания", systemImage: "checkmark.circle") }.tag(2)
            SettingsView().tabItem { Label("Настройки", systemImage: "gearshape") }.tag(3)
        }.tint(AppTheme.violet)
         .task { await store.requestNotifications() }
    }
}

