import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedDate = Date()
    @State private var showImport = false
    @State private var gradingLesson: Lesson?
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
                        ForEach(store.lessons.filter { $0.weekday == day }.sorted { $0.order < $1.order }) { lesson in
                            HStack(spacing: 8) {
                                NavigationLink { LessonEditor(lessonID: lesson.id) } label: { LessonRow(lesson: lesson) }.buttonStyle(.plain)
                                Button { gradingLesson = lesson } label: {
                                    let grade = gradeFor(lesson)
                                    VStack(spacing: 4) { Image(systemName: grade == nil ? "star" : "star.fill"); Text(grade.map(String.init) ?? "+").font(.caption.bold()) }
                                        .foregroundStyle(grade == nil ? AppTheme.violet : .white).frame(width: 48, height: 58)
                                        .background(grade == nil ? AppTheme.violet.opacity(0.12) : AppTheme.coral, in: RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                        if store.lessons.filter({ $0.weekday == day }).isEmpty { ContentUnavailableView("В этот день уроков нет", systemImage: "calendar.badge.checkmark") }
                    }.padding()
                }
            }.background { AnimatedAppBackground() }.navigationTitle("Расписание")
                .toolbar { Button { showImport = true } label: { Label("Импорт", systemImage: "camera.viewfinder") } }
                .sheet(isPresented: $showImport) { ImportScheduleView() }
                .sheet(item: $gradingLesson) { lesson in AddLessonGradeView(lesson: lesson, date: selectedDate) }
        }
    }

    private func gradeFor(_ lesson: Lesson) -> Int? {
        store.grades.first { $0.lessonID == lesson.id && Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }?.value
    }
}

struct AddLessonGradeView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    let lesson: Lesson; let date: Date
    @State private var value = 5; @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Предмет", value: lesson.title)
                LabeledContent("Дата", value: date.formatted(date: .long, time: .omitted))
                Picker("Оценка", selection: $value) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.segmented)
                TextField("За что поставили?", text: $note)
            }.navigationTitle("Оценка за урок").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { store.grades.removeAll { $0.lessonID == lesson.id && Calendar.current.isDate($0.date, inSameDayAs: date) }; store.grades.append(Grade(subject: lesson.title, value: value, date: date, note: note, lessonID: lesson.id)); dismiss() } }
            }
        }
    }
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
        }.navigationTitle("Урок").navigationBarTitleDisplayMode(.inline)
    }
}
