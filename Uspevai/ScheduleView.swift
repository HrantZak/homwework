import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate = Date()
    @State private var showImport = false
    @State private var gradingLesson: Lesson?
    @State private var homeworkLesson: Lesson?
    private var day: Int { Calendar.current.component(.weekday, from: selectedDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    dateHero
                    if !dayLessons.isEmpty {
                        HStack {
                            Text("Уроки").font(.title2.bold())
                            Spacer()
                            Text("\(dayLessons.count) · \(totalDurationText)").font(.caption.bold()).foregroundStyle(.secondary)
                        }.padding(.top, 2)
                    }
                        TimelineView(.periodic(from: .now, by: 30)) { timeline in
                            ForEach(dayLessons) { lesson in
                                lessonCard(lesson, now: timeline.date)
                            }
                        }
                    if dayLessons.isEmpty { ContentUnavailableView("В этот день уроков нет", systemImage: "calendar.badge.checkmark", description: Text("Можно отдохнуть или выполнить задания")) }
                }.padding()
            }
            .background { AnimatedAppBackground() }.navigationTitle("Расписание")
                .toolbar { Button { showImport = true } label: { Label("Импорт", systemImage: "camera.viewfinder") } }
                .sheet(isPresented: $showImport) { ImportScheduleView() }
                .sheet(item: $gradingLesson) { lesson in AddLessonGradeView(lesson: lesson, date: selectedDate) }
                .sheet(item: $homeworkLesson) { lesson in SmartHomeworkEntryView(lesson: lesson, lessonDate: selectedDate).presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        }
    }

    private var dayLessons: [Lesson] { store.lessons.filter { $0.weekday == day }.sorted { $0.order < $1.order } }

    private var dateHero: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.23, green: 0.10, blue: 0.70), AppTheme.violet, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.11)).frame(width: 150).offset(x: 125, y: -48)
            Circle().fill(AppTheme.mint.opacity(0.20)).frame(width: 80).blur(radius: 2).offset(x: -145, y: 80)
            VStack(spacing: 18) {
                HStack {
                    Button { moveDay(-1) } label: { Image(systemName: "chevron.left").frame(width: 42, height: 42).background(.white.opacity(0.14), in: Circle()) }
                    Spacer()
                    DatePicker("Дата", selection: $selectedDate, displayedComponents: .date).labelsHidden().datePickerStyle(.compact).tint(.white).colorScheme(.dark)
                    Spacer()
                    Button { moveDay(1) } label: { Image(systemName: "chevron.right").frame(width: 42, height: 42).background(.white.opacity(0.14), in: Circle()) }
                }
                VStack(spacing: 5) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide))).font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text(selectedDate.formatted(.dateTime.day().month(.wide).year())).font(.subheadline).opacity(0.78)
                }.contentTransition(.numericText()).id(Calendar.current.startOfDay(for: selectedDate))
            }.foregroundStyle(.white).padding(20)
        }
        .frame(height: 168).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: AppTheme.violet.opacity(0.24), radius: 18, y: 9)
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.82), value: selectedDate)
    }

    private func lessonCard(_ lesson: Lesson, now: Date) -> some View {
        let items = Array(homeworkFor(lesson).prefix(2))
        let ended = lessonHasEnded(lesson, now: now)
        return SoftCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    VStack(spacing: 3) {
                        Text(lesson.startsAt).font(.headline.monospacedDigit())
                        Text(lesson.endsAt).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }.frame(width: 54).padding(.vertical, 10).background(AppTheme.violet.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))

                    Capsule().fill(LinearGradient(colors: [AppTheme.violet, AppTheme.blue], startPoint: .top, endPoint: .bottom)).frame(width: 4, height: 50)

                    NavigationLink { LessonEditor(lessonID: lesson.id) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(lesson.title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                            HStack(spacing: 5) {
                                Text("\(lesson.order)-й урок")
                                if !lesson.teacher.isEmpty { Text("·"); Text(lesson.teacher).lineLimit(1) }
                            }.font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)

                Button { gradingLesson = lesson } label: {
                    let grade = gradeFor(lesson)
                    Text(grade.map(String.init) ?? "+").font(.title3.bold()).contentTransition(.numericText())
                        .foregroundStyle(grade == nil ? AppTheme.violet : .white).frame(width: 46, height: 46)
                        .background(grade == nil ? AppTheme.violet.opacity(0.09) : gradeColor(grade!), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }.buttonStyle(ScalePressStyle())
            }

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "book.closed.fill").font(.title3).foregroundStyle(item.isDone ? AppTheme.mint : AppTheme.violet)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.text).font(.subheadline.weight(.semibold)).strikethrough(item.isDone).lineLimit(2)
                        Text("До \(item.dueDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).hour().minute()))").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { withAnimation(.bouncy) { toggleHomework(item) } } label: { Image(systemName: item.isDone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle").font(.title3) }.buttonStyle(.plain).foregroundStyle(AppTheme.mint)
                }
                .padding(12).background(AppTheme.violet.opacity(0.065), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if ended {
                Button { homeworkLesson = lesson } label: {
                    HStack { Image(systemName: "square.and.pencil"); Text(items.isEmpty ? "Записать домашнее задание" : "Добавить ещё"); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).opacity(0.55) }
                        .font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 12).foregroundStyle(.white)
                        .background(LinearGradient(colors: [AppTheme.violet, AppTheme.blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(ScalePressStyle())
                    .transition(.asymmetric(insertion: .scale(scale: 0.86).combined(with: .opacity), removal: .opacity))
            }
        }
        }
        .scrollTransition(.animated(reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.45, dampingFraction: 0.86))) { content, phase in
            content.opacity(phase.isIdentity ? 1 : 0.68).scaleEffect(phase.isIdentity ? 1 : 0.965)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.82), value: ended)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.84), value: items)
    }

    private var totalDurationText: String {
        let minutes = dayLessons.reduce(0) { $0 + max(0, timeMinutes($1.endsAt) - timeMinutes($1.startsAt)) }
        return "\(minutes / 60) ч \(minutes % 60) мин"
    }
    private func moveDay(_ value: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: value, to: selectedDate) else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82)) { selectedDate = date }
    }
    private func timeMinutes(_ value: String) -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
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
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        LinearGradient(colors: [AppTheme.violet, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Circle().fill(.white.opacity(0.12)).frame(width: 110).offset(x: 145, y: -42)
                        HStack(spacing: 14) {
                            Image(systemName: "book.closed.fill").font(.title2.bold()).foregroundStyle(.white).frame(width: 52, height: 52).background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 17))
                            VStack(alignment: .leading, spacing: 4) { Text("УРОК ЗАКОНЧИЛСЯ").font(.caption2.bold()).tracking(1.2).opacity(0.75); Text(lesson.title).font(.title3.bold()).lineLimit(2) }
                            Spacer()
                        }.foregroundStyle(.white).padding(18)
                    }.frame(height: 104).clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))

                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Что задали?", systemImage: "square.and.pencil").font(.headline)
                            TextField("Например: выучить правило и решить № 5", text: $text, axis: .vertical)
                                .lineLimit(3...6).padding(12).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Срок выполнения", systemImage: "calendar.badge.clock").font(.headline)
                            DatePicker("До следующего урока", selection: $dueDate).datePickerStyle(.compact).tint(AppTheme.violet)
                            Text("Мы нашли следующий урок автоматически. Дату можно изменить.").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Button { save() } label: {
                        Label("Сохранить задание", systemImage: "checkmark.circle.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(.white)
                            .background(LinearGradient(colors: [AppTheme.violet, AppTheme.blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 17))
                    }.buttonStyle(ScalePressStyle()).disabled(trimmedText.isEmpty).opacity(trimmedText.isEmpty ? 0.5 : 1)
                }.padding()
            }
            .background { AnimatedAppBackground() }.navigationTitle("Новое задание").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
            .onAppear { dueDate = nextLessonDate }
        }
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func save() { guard !trimmedText.isEmpty else { return }; store.addHomework(for: lesson, text: trimmedText, dueDate: dueDate); dismiss() }

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
