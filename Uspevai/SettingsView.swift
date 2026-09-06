import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("interfaceMotionEnabled") private var motionEnabled = true
    var body: some View {
        NavigationStack {
            Form {
                Section("Напоминания") { Toggle("В начале урока", isOn: $store.remindersEnabled); Text("Когда урок начнётся, напомним записать домашнее задание.").font(.caption).foregroundStyle(.secondary) }
                Section("Внешний вид") {
                    Toggle(isOn: $store.darkMode) { Label("Тёмная тема", systemImage: "moon.fill") }
                    Toggle(isOn: $motionEnabled) { Label("Плавные анимации", systemImage: "sparkles") }
                    Text("Отключи для спокойного интерфейса. Системное уменьшение движения всегда имеет приоритет.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Учебный период") { DatePicker("Конец четверти", selection: $store.termEnd, displayedComponents: .date) }
                Section("Приложение") {
                    LabeledContent("Версия", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    LabeledContent("Сборка", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }.scrollContentBackground(.hidden).background { AnimatedAppBackground() }.navigationTitle("Настройки")
        }
    }
}
