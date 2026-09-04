import SwiftUI

struct HomeworkView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAdd = false
    @State private var filter = 0
    private var visibleIDs: [UUID] {
        store.homework
            .filter { filter == 0 || (filter == 1 && !$0.isDone) || (filter == 2 && $0.isDone) }
            .sorted { lhs, rhs in lhs.isDone == rhs.isDone ? lhs.dueDate < rhs.dueDate : !lhs.isDone }
            .map(\.id)
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    homeworkSummary.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section {
                    Picker("Фильтр", selection: $filter) { Text("Все").tag(0); Text("Активные").tag(1); Text("Готово").tag(2) }
                        .pickerStyle(.segmented)
                }
                ForEach(visibleIDs, id: \.self) { id in
                    if let index = store.homework.firstIndex(where: { $0.id == id }) {
                    let item = store.homework[index]
                    Button { withAnimation(.bouncy) { store.homework[index].isDone.toggle() } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(item.isDone ? AppTheme.mint : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.text).strikethrough(item.isDone).foregroundStyle(.primary)
                                Text("\(item.lessonTitle) • \(dueText(item.dueDate, done: item.isDone))").font(.caption).foregroundStyle(!item.isDone && item.dueDate < Calendar.current.startOfDay(for: .now) ? AppTheme.coral : .secondary)
                            }
                        }.padding(.vertical, 6)
                    }.buttonStyle(.plain)
                    }
                }.onDelete { offsets in
                    let ids = offsets.map { visibleIDs[$0] }
                    store.homework.removeAll { ids.contains($0.id) }
                }
            }.scrollContentBackground(.hidden).background { AnimatedAppBackground() }.overlay { if visibleIDs.isEmpty { ContentUnavailableView(store.homework.isEmpty ? "Заданий пока нет" : "Здесь пока пусто", systemImage: "checkmark.seal", description: Text(store.homework.isEmpty ? "Добавь первое задание кнопкой +" : "Выбери другой фильтр")) } }
                .navigationTitle("Задания").toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
                .sheet(isPresented: $showAdd) { AddHomeworkView() }
        }
    }

    private var homeworkSummary: some View {
        let done = store.homework.filter(\.isDone).count
        let active = store.homework.count - done
        return ZStack(alignment: .bottomLeading) {
            AppTheme.heroGradient
            Circle().fill(.white.opacity(0.12)).frame(width: 130).offset(x: 250, y: -42)
            VStack(alignment: .leading, spacing: 13) {
                Label("МОЙ ПРОГРЕСС", systemImage: "checkmark.seal.fill").font(.caption.bold()).tracking(1.2).opacity(0.78)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(active)").font(.system(size: 36, weight: .heavy, design: .rounded)).contentTransition(.numericText())
                    Text(active == 1 ? "задание осталось" : "заданий осталось").font(.subheadline.bold()).opacity(0.82)
                    Spacer()
                    Text("\(done) готово").font(.caption.bold()).padding(.horizontal, 11).frame(height: 32).background(.white.opacity(0.13), in: Capsule())
                }
                ProgressView(value: Double(done), total: Double(max(1, store.homework.count))).tint(.white)
            }.foregroundStyle(.white).padding(20)
        }.frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.16)) }
            .shadow(color: AppTheme.violet.opacity(0.25), radius: 20, y: 10)
    }

    private func dueText(_ date: Date, done: Bool) -> String {
        if done { return "выполнено" }
        if date < Calendar.current.startOfDay(for: .now) { return "срок прошёл" }
        if Calendar.current.isDateInToday(date) { return "сегодня" }
        if Calendar.current.isDateInTomorrow(date) { return "завтра" }
        return "до \(date.formatted(date: .abbreviated, time: .omitted))"
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
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { if let id = lessonID, let lesson = store.lessons.first(where: {$0.id == id}) { store.addHomework(for: lesson, text: text, dueDate: dueDate); dismiss() } }.disabled(lessonID == nil || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}
