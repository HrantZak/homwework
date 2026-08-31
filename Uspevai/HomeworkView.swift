import SwiftUI

struct HomeworkView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAdd = false
    var body: some View {
        NavigationStack {
            List {
                ForEach($store.homework) { $item in
                    Button { withAnimation(.bouncy) { item.isDone.toggle() } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(item.isDone ? AppTheme.mint : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.text).strikethrough(item.isDone).foregroundStyle(.primary)
                                Text("\(item.lessonTitle) • до \(item.dueDate.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6)
                    }.buttonStyle(.plain)
                }.onDelete { store.homework.remove(atOffsets: $0) }
            }.scrollContentBackground(.hidden).background { AnimatedAppBackground() }.overlay { if store.homework.isEmpty { ContentUnavailableView("Заданий пока нет", systemImage: "checkmark.seal", description: Text("Добавь первое задание кнопкой +")) } }
                .navigationTitle("Задания").toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
                .sheet(isPresented: $showAdd) { AddHomeworkView() }
        }
    }
}

struct AddHomeworkView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var lessonID: UUID?
    @State private var text = ""
    @State private var dueDate = Date().addingTimeInterval(86400)
    var body: some View {
        NavigationStack {
            Form {
                Picker("Предмет", selection: $lessonID) { Text("Выберите").tag(UUID?.none); ForEach(Array(Set(store.lessons.map(\.title))).sorted(), id: \.self) { title in Text(title).tag(store.lessons.first(where: {$0.title == title})?.id as UUID?) } }
                TextField("Что нужно сделать?", text: $text, axis: .vertical).lineLimit(3...6)
                DatePicker("Срок", selection: $dueDate, displayedComponents: .date)
            }.navigationTitle("Новое задание").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { if let id = lessonID, let lesson = store.lessons.first(where: {$0.id == id}) { store.addHomework(for: lesson, text: text, dueDate: dueDate); dismiss() } }.disabled(lessonID == nil || text.isEmpty) }
            }
        }
    }
}
