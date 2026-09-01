import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedDate = Date()
    @State private var showImport = false
    @State private var gradingLesson: Lesson?
    @State private var homeworkLesson: Lesson?
    private var day: Int { Calendar.current.component(.weekday, from: selectedDate) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Button { withAnimation(.snappy) { selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)! } } label: { Image(systemName: "chevron.left") }.buttonStyle(ScalePressStyle())
                    DatePicker("Дата", selection: $selectedDate, displayedComponents: .date).labelsHidden().datePickerStyle(.compact)
                    Button { withAnimation(.snappy) { selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)! } } label: { Image(systemName: "chevron.right") }.buttonStyle(ScalePressStyle())
                }.font(.title3.bold()).padding(.horizontal)
                Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.headline).foregroundStyle(AppTheme.violet).contentTransition(.numericText()).id(selectedDate)
                ScrollView {
                    LazyVStack(spacing: 13) {
                        TimelineView(.periodic(from: .now, by: 30)) { timeline in
                            ForEach(store.lessons.filter { $0.weekday == day }.sorted { $0.order < $1.order }) { lesson in
                                lessonCard(lesson, now: timeline.date)
                            }
                        }
                        if store.lessons.filter({ $0.weekday == day }).isEmpty { ContentUnavailableView("В этот день уроков нет", systemImage: "calendar.badge.checkmark") }
                    }.padding()
                }
            }.background { AnimatedAppBackground() }.navigationTitle("Расписание")
                .toolbar { Button { showImport = true } label: { Label("Импорт", systemImage: "camera.viewfinder") } }
                .sheet(isPresented: $showImport) { ImportScheduleView() }
                .sheet(item: $gradingLesson) { lesson in AddLessonGradeView(lesson: lesson, date: selectedDate) }
                .sheet(item: $homeworkLesson) { lesson in SmartHomeworkEntryView(lesson: lesson, lessonDate: selectedDate) }
        }
    }

    private func lessonCard(_ lesson: Lesson, now: Date) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                NavigationLink { LessonEditor(lessonID: lesson.id) } label: { LessonRow(lesson: lesson) }.buttonStyle(.plain)
                Button { gradingLesson = lesson } label: {
                    let grade = gradeFor(lesson)
                    VStack(spacing: 2) { Text(grade.map(String.init) ?? "+").font(.title3.bold()).contentTransition(.numericText()); Text("БАЛЛ").font(.system(size: 7, weight: .heavy)).tracking(0.7) }
                        .foregroundStyle(grade == nil ? AppTheme.violet : .white).frame(width: 56, height: 56)
                        .background(grade == nil ? AppTheme.violet.opacity(0.10) : gradeColor(grade!), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 15).stroke(grade == nil ? AppTheme.violet.opacity(0.35) : .white.opacity(0.25), lineWidth: 1.5) }
                        .shadow(color: grade == nil ? .clear : gradeColor(grade!).opacity(0.28), radius: 7, y: 4)
                }.buttonStyle(ScalePressStyle())
            }

            ForEach(Array(homeworkFor(lesson).prefix(2))) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "book.closed.fill").foregroundStyle(item.isDone ? AppTheme.mint : AppTheme.violet)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.text).font(.subheadline.bold()).strikethrough(item.isDone).lineLimit(2)
                        Text("До \(item.dueDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).hour().minute()))").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { withAnimation(.bouncy) { toggleHomework(item) } } label: { Image(systemName: item.isDone ? "arrow.uturn.backward.circle" : "checkmark.circle") }.buttonStyle(.plain).foregroundStyle(AppTheme.mint)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppTheme.violet.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if lessonHasEnded(lesson, now: now) {
                Button { homeworkLesson = lesson } label: {
                    Label(homeworkFor(lesson).isEmpty ? "Записать домашнее задание" : "Добавить ещё задание", systemImage: "square.and.pencil")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 11)
                        .foregroundStyle(AppTheme.violet).background(AppTheme.violet.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(ScalePressStyle())
            }
        }
    }

    private func gradeFor(_ lesson: Lesson) -> Int? {
        store.grades.first { $0.lessonID == lesson.id && Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }?.value
    }
    private func homeworkFor(_ lesson: Lesson) -> [Homework] {
        store.homework.filter { item in
            let createdHere = item.lessonID == lesson.id && item.createdAt.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } == true
            let dueHere = item.lessonTitle == lesson.title && Calendar.current.isDate(item.dueDate, inSameDayAs: selectedDate)
            return createdHere || dueHere
        }.sorted { $0.isDone == $1.isDone ? $0.dueDate < $1.dueDate : !$0.isDone }
    }
    private func lessonHasEnded(_ lesson: Lesson, now: Date) -> Bool {
        guard Calendar.current.isDateInToday(selectedDate), let end = dateTime(lesson.endsAt, on: selectedDate) else { return false }
        return now >= end
    }
    private func dateTime(_ text: String, on date: Date) -> Date? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date)
    }
    private func toggleHomework(_ item: Homework) {
        guard let index = store.homework.firstIndex(where: { $0.id == item.id }) else { return }
        store.homework[index].isDone.toggle()
    }
    private func gradeColor(_ value: Int) -> Color { value >= 8 ? AppTheme.mint : value >= 6 ? .blue : value >= 4 ? .orange : AppTheme.coral }
}

struct SmartHomeworkEntryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let lesson: Lesson
    let lessonDate: Date
    @State private var text = ""
    @State private var dueDate: Date

    init(lesson: Lesson, lessonDate: Date) {
        self.lesson = lesson
        self.lessonDate = lessonDate
        _dueDate = State(initialValue: lessonDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Урок закончился") {
                    LabeledContent("Предмет", value: lesson.title)
                    TextField("Что задали?", text: $text, axis: .vertical).lineLimit(3...7)
                }
                Section {
                    DatePicker("Сделать до", selection: $dueDate)
                } footer: {
                    Text("Срок автоматически поставлен на начало следующего урока по этому предмету. При необходимости его можно изменить.")
                }
            }
            .navigationTitle("Домашнее задание").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { store.addHomework(for: lesson, text: text, dueDate: dueDate); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { dueDate = nextLessonDate }
        }
    }

    private var nextLessonDate: Date {
        let calendar = Calendar.current
        let baseWeekday = calendar.component(.weekday, from: lessonDate)
        let currentEnd = minutes(lesson.endsAt)
        let candidates = store.lessons.filter { $0.title == lesson.title }.compactMap { candidate -> Date? in
            var days = (candidate.weekday - baseWeekday + 7) % 7
            if days == 0 && minutes(candidate.startsAt) <= currentEnd { days = 7 }
            guard let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: lessonDate)) else { return nil }
            let parts = candidate.startsAt.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return day }
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
        }
        return candidates.filter { $0 > lessonDate }.min() ?? calendar.date(byAdding: .day, value: 7, to: lessonDate)!
    }

    private func minutes(_ value: String) -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
    }
}

struct AddLessonGradeView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    let lesson: Lesson; let date: Date
    @State private var value = 10; @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Предмет", value: lesson.title)
                LabeledContent("Дата", value: date.formatted(date: .long, time: .omitted))
                Section("Выбери балл") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(1...10, id: \.self) { number in
                            Button { withAnimation(.bouncy) { value = number } } label: { Text("\(number)").font(.title3.bold()).frame(maxWidth: .infinity).frame(height: 46).foregroundStyle(value == number ? .white : gradeColor(number)).background(value == number ? gradeColor(number) : gradeColor(number).opacity(0.11), in: RoundedRectangle(cornerRadius: 13)) }.buttonStyle(ScalePressStyle())
                        }
                    }.padding(.vertical, 5)
                }
                TextField("За что поставили?", text: $note)
            }.navigationTitle("Оценка за урок").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { store.grades.removeAll { $0.lessonID == lesson.id && Calendar.current.isDate($0.date, inSameDayAs: date) }; store.grades.append(Grade(subject: lesson.title, value: value, date: date, note: note, lessonID: lesson.id)); dismiss() } }
            }
        }
    }
    private func gradeColor(_ value: Int) -> Color { value >= 8 ? AppTheme.mint : value >= 6 ? .blue : value >= 4 ? .orange : AppTheme.coral }
}

struct LessonEditor: View {
    @EnvironmentObject var store: AppStore
    let lessonID: UUID
    var index: Int? { store.lessons.firstIndex { $0.id == lessonID } }
    var body: some View {
        Form {
            if let index {
                TextField("Предмет", text: $store.lessons[index].title)
                TextField("Преподаватель", text: $store.lessons[index].teacher)
                TextField("Начало", text: $store.lessons[index].startsAt).keyboardType(.numbersAndPunctuation)
                TextField("Конец", text: $store.lessons[index].endsAt).keyboardType(.numbersAndPunctuation)
            }
        }.navigationTitle("Урок").navigationBarTitleDisplayMode(.inline).onDisappear { store.refreshNotifications() }
    }
}
