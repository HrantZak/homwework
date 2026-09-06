import SwiftUI

struct IncomingPlanView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let messageID: String
    let lessons: [Lesson]
    let homework: [Homework]
    private var valid: Bool {
        if !lessons.isEmpty { return PlannerLogic.validSchedule(lessons) }
        return !homework.isEmpty && homework.count <= 50 && Set(homework.map(\.id)).count == homework.count && homework.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 2000 }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Сначала проверь изменения", systemImage: "checkmark.shield.fill").font(.headline)
                    Text(lessons.isEmpty ? "Добавим новые задания. Уже существующие записи не изменятся; выполнение друга не переносится." : "Это замена всего недельного расписания. Текущая версия попадёт в корзину. Твои задания и оценки останутся.").font(.subheadline).foregroundStyle(.secondary)
                }
                if !lessons.isEmpty {
                    Section("Сейчас · \(store.lessons.count) уроков") {
                        ForEach(store.lessons.sorted { ($0.weekday, $0.order) < ($1.weekday, $1.order) }) { lesson in row(lesson) }
                    }
                    Section("Предложено другом · \(lessons.count) уроков") {
                        ForEach(lessons.sorted { ($0.weekday, $0.order) < ($1.weekday, $1.order) }) { lesson in row(lesson) }
                    }
                } else {
                    Section("Задания друга") { ForEach(homework) { item in VStack(alignment: .leading) { Text(item.text); Text("\(item.lessonTitle) · \(item.dueDate.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) } } }
                }
                if !valid { Text("Данные неполные или некорректные. Попроси друга отправить их заново.").foregroundStyle(.red) }
            }.navigationTitle("Проверка перед принятием").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Принять") {
                            if !lessons.isEmpty { store.acceptSchedule(lessons, messageID: messageID) }
                            else {
                                let existing = Set(store.homework.map(\.id))
                                store.homework.append(contentsOf: homework.filter { !existing.contains($0.id) }.map { value in var value = value; value.isDone = false; value.lessonID = nil; return value })
                                store.planner.acceptedMessages.append(messageID)
                                store.flushSaves()
                            }
                            dismiss()
                        }.disabled(!valid || store.planner.acceptedMessages.contains(messageID))
                    }
                }
        }
    }
    private func row(_ lesson: Lesson) -> some View {
        let same = store.lessons.contains { $0.weekday == lesson.weekday && $0.order == lesson.order && $0.title == lesson.title && $0.startsAt == lesson.startsAt && $0.endsAt == lesson.endsAt }
        return VStack(alignment: .leading, spacing: 5) {
            Text(lesson.title).font(.headline)
            Text("\([1: "Вс", 2: "Пн", 3: "Вт", 4: "Ср", 5: "Чт", 6: "Пт", 7: "Сб"][lesson.weekday] ?? "?") · \(lesson.startsAt)–\(lesson.endsAt)").font(.caption)
            Text(same ? "Совпадает с твоим расписанием" : "Отличается от твоего расписания").font(.caption).foregroundStyle(.secondary)
        }
    }
}
