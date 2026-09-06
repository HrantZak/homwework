import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("interfaceMotionEnabled") private var motionEnabled = true
    @State private var selection = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                TodayView().tabItem { Label("Сегодня", systemImage: "sparkles") }.tag(0)
                ScheduleView().tabItem { Label("Расписание", systemImage: "calendar") }.tag(1)
                MarketplaceView().tabItem { Label("Маркет", systemImage: "bag.fill") }.tag(2)
                HomeworkView().tabItem { Label("Задания", systemImage: "checkmark.circle") }.tag(3)
                ProfileView().tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }.tag(4)
            }.font(store.activeAppFont).tint(AppTheme.violet).toolbarBackground(.regularMaterial, for: .tabBar).toolbarBackground(.visible, for: .tabBar)
                .sensoryFeedback(.selection, trigger: selection)
                .environment(\.appReduceMotion, !motionEnabled)
        }.onChange(of: scenePhase) { _, phase in if phase != .active { store.flushSaves() } }.task {
            store.refreshNotifications()
            if store.remindersEnabled { await store.requestNotifications() }
        }
    }
}
