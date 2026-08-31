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
                                    VStack(spacing: 2) { Text(grade.map(String.init) ?? "+").font(.title3.bold()).contentTransition(.numericText()); Text("БАЛЛ").font(.system(size: 7, weight: .heavy)).tracking(0.7) }
                                        .foregroundStyle(grade == nil ? AppTheme.violet : .white).frame(width: 56, height: 56)
                                        .background(grade == nil ? AppTheme.violet.opacity(0.10) : gradeColor(grade!), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                        .overlay { RoundedRectangle(cornerRadius: 15).stroke(grade == nil ? AppTheme.violet.opacity(0.35) : .white.opacity(0.25), lineWidth: 1.5) }
                                        .shadow(color: grade == nil ? .clear : gradeColor(grade!).opacity(0.28), radius: 9, y: 5)
                                }.buttonStyle(ScalePressStyle())
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
    private func gradeColor(_ value: Int) -> Color { value >= 8 ? AppTheme.mint : value >= 6 ? .blue : value >= 4 ? .orange : AppTheme.coral }
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
        }.navigationTitle("Урок").navigationBarTitleDisplayMode(.inline)
    }
}
