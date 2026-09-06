import SwiftUI

struct ScheduleManagerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay = 2
    @State private var editingLesson: Lesson?
    @State private var showAddLesson = false
    @State private var lessonToDelete: Lesson?

    private let days = [(2, "Пн"), (3, "Вт"), (4, "Ср"), (5, "Чт"), (6, "Пт")]
    private var lessons: [Lesson] { store.lessons.filter { $0.weekday == selectedDay }.sorted { $0.order < $1.order } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dayPicker
                List {
                    Section {
                        tableHeader
                        if lessons.isEmpty {
                            ContentUnavailableView("Уроков нет", systemImage: "calendar.badge.plus", description: Text("Добавь первый урок этого дня"))
                                .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                        } else {
                            ForEach(lessons) { lesson in lessonRow(lesson) }
                                .onMove(perform: moveLessons)
                        }
                    } header: {
                        HStack { Text(fullDayName(selectedDay)); Spacer(); Text("\(lessons.count) уроков") }
                    }

                    Section {
                        Button { showAddLesson = true } label: {
                            Label("Добавить урок", systemImage: "plus.circle.fill").font(.headline).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 5)
                        }.tint(AppTheme.violet)
                    }
                }
                .listStyle(.insetGrouped).scrollContentBackground(.hidden).background { AnimatedAppBackground() }
            }
            .navigationTitle("Всё расписание").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
            .sheet(item: $editingLesson) { lesson in ScheduleLessonForm(day: selectedDay, lessonID: lesson.id) }
            .sheet(isPresented: $showAddLesson) { ScheduleLessonForm(day: selectedDay, lessonID: nil) }
            .confirmationDialog("Удалить урок?", isPresented: Binding(get: { lessonToDelete != nil }, set: { if !$0 { lessonToDelete = nil } }), titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { deleteLesson() }
                Button("Отмена", role: .cancel) { lessonToDelete = nil }
            } message: { Text(lessonToDelete?.title ?? "") }
            .onDisappear { store.refreshNotifications() }
        }
    }

    private var dayPicker: some View {
        HStack(spacing: 7) {
            ForEach(days.indices, id: \.self) { index in
                let value = days[index].0
                let title = days[index].1
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedDay = value }
                } label: {
                    VStack(spacing: 4) {
                        Text(title).font(.subheadline.bold())
                        Text("\(store.lessons.filter { $0.weekday == value }.count)").font(.caption2)
                    }.frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(selectedDay == value ? .white : .primary)
                        .background(selectedDay == value ? AppTheme.violet : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                }.buttonStyle(ScalePressStyle())
            }
        }.padding(.horizontal).padding(.top, 10).padding(.bottom, 4)
    }

    private var tableHeader: some View {
        HStack(spacing: 10) {
            Text("№").frame(width: 24)
            Text("Время").frame(width: 82, alignment: .leading)
            Text("Предмет").frame(maxWidth: .infinity, alignment: .leading)
        }.font(.caption2.bold()).foregroundStyle(.secondary).textCase(.uppercase).listRowBackground(AppTheme.violet.opacity(0.07))
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        Button { editingLesson = lesson } label: {
            HStack(spacing: 10) {
                Text("\(lesson.order)").font(.caption.bold()).foregroundStyle(AppTheme.violet).frame(width: 24, height: 24).background(AppTheme.violet.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.startsAt).font(.subheadline.monospacedDigit().bold())
                    Text(lesson.endsAt).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }.frame(width: 82, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(lesson.title).font(.subheadline.bold()).lineLimit(2)
                    if !lesson.teacher.isEmpty { Text(lesson.teacher).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }.padding(.vertical, 5).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .swipeActions { Button(role: .destructive) { lessonToDelete = lesson } label: { Label("Удалить", systemImage: "trash") } }
    }

    private func moveLessons(from offsets: IndexSet, to destination: Int) {
        var reordered = lessons
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, lesson) in reordered.enumerated() {
            guard let storeIndex = store.lessons.firstIndex(where: { $0.id == lesson.id }) else { continue }
            store.lessons[storeIndex].order = index + 1
        }
    }

    private func deleteLesson() {
        guard let lesson = lessonToDelete else { return }
        store.archiveSchedule()
        store.lessons.removeAll { $0.id == lesson.id }
        lessonToDelete = nil
        renumberCurrentDay()
    }

    private func renumberCurrentDay() {
        for (index, lesson) in lessons.enumerated() {
            guard let storeIndex = store.lessons.firstIndex(where: { $0.id == lesson.id }) else { continue }
            store.lessons[storeIndex].order = index + 1
        }
    }

    private func fullDayName(_ day: Int) -> String { [2: "Понедельник", 3: "Вторник", 4: "Среда", 5: "Четверг", 6: "Пятница"][day] ?? "День" }
}

struct ScheduleLessonForm: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let lessonID: UUID?
    @State private var day: Int
    @State private var title = ""
    @State private var teacher = ""
    @State private var startsAt = ScheduleLessonForm.time(hour: 9, minute: 0)
    @State private var endsAt = ScheduleLessonForm.time(hour: 9, minute: 45)

    init(day: Int, lessonID: UUID?) {
        self.lessonID = lessonID
        _day = State(initialValue: day)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Урок") {
                    TextField("Название предмета", text: $title)
                    TextField("Преподаватель — необязательно", text: $teacher)
                    Picker("День недели", selection: $day) {
                        Text("Понедельник").tag(2); Text("Вторник").tag(3); Text("Среда").tag(4); Text("Четверг").tag(5); Text("Пятница").tag(6)
                    }
                }
                Section("Время") {
                    DatePicker("Начало", selection: $startsAt, displayedComponents: .hourAndMinute)
                    DatePicker("Окончание", selection: $endsAt, in: startsAt..., displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle(lessonID == nil ? "Новый урок" : "Редактирование").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .onAppear { loadLesson() }
        }
    }

    private func loadLesson() {
        guard let lessonID, let lesson = store.lessons.first(where: { $0.id == lessonID }) else { return }
        day = lesson.weekday; title = lesson.title; teacher = lesson.teacher
        startsAt = Self.date(from: lesson.startsAt); endsAt = Self.date(from: lesson.endsAt)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        if let lessonID, let index = store.lessons.firstIndex(where: { $0.id == lessonID }) {
            let previousDay = store.lessons[index].weekday
            if previousDay != day { store.lessons[index].order = (store.lessons.filter { $0.weekday == day }.map(\.order).max() ?? 0) + 1 }
            store.lessons[index].weekday = day; store.lessons[index].title = cleanTitle; store.lessons[index].teacher = teacher.trimmingCharacters(in: .whitespacesAndNewlines)
            store.lessons[index].startsAt = Self.string(from: startsAt); store.lessons[index].endsAt = Self.string(from: endsAt)
            if previousDay != day { renumber(previousDay) }
        } else {
            let order = (store.lessons.filter { $0.weekday == day }.map(\.order).max() ?? 0) + 1
            store.lessons.append(Lesson(weekday: day, order: order, title: cleanTitle, teacher: teacher.trimmingCharacters(in: .whitespacesAndNewlines), startsAt: Self.string(from: startsAt), endsAt: Self.string(from: endsAt)))
        }
        store.lessons.sort { ($0.weekday, $0.order) < ($1.weekday, $1.order) }
        store.refreshNotifications(); dismiss()
    }

    private func renumber(_ weekday: Int) {
        let lessons = store.lessons.filter { $0.weekday == weekday }.sorted { $0.order < $1.order }
        for (position, lesson) in lessons.enumerated() {
            guard let index = store.lessons.firstIndex(where: { $0.id == lesson.id }) else { continue }
            store.lessons[index].order = position + 1
        }
    }

    private static func time(hour: Int, minute: Int) -> Date { Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date() }
    private static func date(from value: String) -> Date {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? time(hour: parts[0], minute: parts[1]) : time(hour: 9, minute: 0)
    }
    private static func string(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }
}
