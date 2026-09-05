import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = 0
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLaunch = true

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
            if showLaunch { LaunchView().transition(.opacity.combined(with: .scale(scale: 1.08))) }
        }.onChange(of: scenePhase) { _, phase in if phase != .active { store.flushSaves() } }.task {
            store.refreshNotifications()
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 650))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { showLaunch = false }
            if store.remindersEnabled { await store.requestNotifications() }
        }
    }
}

private struct LaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.18, green: 0.06, blue: 0.58), AppTheme.violet, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(.white.opacity(0.12)).frame(width: 280).blur(radius: 3).scaleEffect(animate ? 1.35 : 0.75)
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 78, weight: .bold)).foregroundStyle(.white, AppTheme.mint).symbolEffect(.bounce, value: animate)
                Text("Успевай").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text("Твой учебный ритм").font(.subheadline.bold()).tracking(1.2).foregroundStyle(.white.opacity(0.75))
            }.scaleEffect(animate ? 1 : 0.82).opacity(animate ? 1 : 0)
        }.onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.7)) { animate = true } }
    }
}
