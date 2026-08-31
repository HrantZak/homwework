import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        NavigationStack {
            Form {
                Section("Напоминания") { Toggle("В конце урока", isOn: $store.remindersEnabled); Text("Напомним записать домашнее задание сразу после звонка.").font(.caption).foregroundStyle(.secondary) }
                Section("Внешний вид") { Toggle("Тёмная тема", isOn: $store.darkMode) }
                Section("Учебный период") { DatePicker("Конец четверти", selection: $store.termEnd, displayedComponents: .date) }
                Section("Приложение") {
                    LabeledContent("Версия", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    LabeledContent("Сборка", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }.scrollContentBackground(.hidden).background { AnimatedAppBackground() }.navigationTitle("Настройки")
        }
    }
}
