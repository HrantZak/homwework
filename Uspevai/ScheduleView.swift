import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: AppStore
    @AppReduceMotion private var reduceMotion
    @State private var selectedDate = Date()
    @State private var showImport = false
    @State private var showScheduleManager = false
    @State private var gradingLesson: Lesson?
    @State private var homeworkLesson: Lesson?
    @State private var showDayOverride = false
    private var day: Int { appCalendar.component(.weekday, from: selectedDate) }
    private var appCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.timeZone = .current
        return calendar
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    dateHero
                    weekPicker
                    if let override = store.override(on: selectedDate) { overrideBanner(override) }
                    if !dayLessons.isEmpty {
                        SectionHeader(title: "Уроки", subtitle: "\(dayLessons.count) · \(totalDurationText)", symbol: "clock.badge.checkmark.fill").padding(.top, 2)
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
                .toolbar {
                    NavigationLink { GradebookView() } label: { Image(systemName: "chart.bar.doc.horizontal.fill") }.accessibilityLabel("Журнал оценок")
                    Menu {
                        Button { showScheduleManager = true } label: { Label("Всё расписание", systemImage: "tablecells") }
                        Button { showImport = true } label: { Label("Импорт с фото", systemImage: "camera.viewfinder") }
                        Button { showDayOverride = true } label: { Label("Заменить день", systemImage: "arrow.triangle.2.circlepath.calendar") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                .sheet(isPresented: $showImport) { ImportScheduleView() }
                .sheet(isPresented: $showScheduleManager) { ScheduleManagerView() }
                .sheet(item: $gradingLesson) { lesson in AddLessonGradeView(lesson: lesson, date: selectedDate) }
                .sheet(item: $homeworkLesson) { lesson in SmartHomeworkEntryView(lesson: lesson, lessonDate: selectedDate).presentationDetents([.large]).presentationDragIndicator(.visible) }
                .sheet(isPresented: $showDayOverride) { DayOverrideView(date: selectedDate) }
        }
    }

    private var dayLessons: [Lesson] { store.lessons(on: selectedDate) }

    private func overrideBanner(_ override: ScheduleOverride) -> some View {
        HStack(spacing: 12) {
            Image(systemName: override.sourceWeekday == nil ? "moon.stars.fill" : "arrow.triangle.2.circlepath.calendar").foregroundStyle(AppTheme.violet).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(override.sourceWeekday.map { "Расписание: \(weekdayName($0))" } ?? "День без уроков").font(.subheadline.bold())
                Text(override.note.isEmpty ? "Разовая замена только для этой даты" : override.note).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { store.clearScheduleOverride(on: selectedDate) } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Отменить замену")
        }.padding(14).background(AppTheme.violet.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
    }

    private func weekdayName(_ value: Int) -> String { [2:"понедельника",3:"вторника",4:"среды",5:"четверга",6:"пятницы",7:"субботы",1:"воскресенья"][value] ?? "другого дня" }

    private var dateHero: some View {
        ZStack {
            OrbitBackdrop()
            VStack(spacing: 18) {
                HStack {
                    Button { moveDay(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44).background(.white.opacity(0.14), in: Circle()) }.accessibilityLabel("Предыдущий день")
                    Spacer()
                    DatePicker("Дата", selection: $selectedDate, displayedComponents: .date).labelsHidden().datePickerStyle(.compact).tint(.white).colorScheme(.dark)
                    Spacer()
                    Button { moveDay(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44).background(.white.opacity(0.14), in: Circle()) }.accessibilityLabel("Следующий день")
                }
                VStack(spacing: 5) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide))).font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text(selectedDate.formatted(.dateTime.day().month(.wide).year())).font(.subheadline).opacity(0.78)
                }.contentTransition(.numericText()).id(Calendar.current.startOfDay(for: selectedDate))
            }.foregroundStyle(.white).padding(20)
        }
        .fixedSize(horizontal: false, vertical: true).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .buttonStyle(ScalePressStyle())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: selectedDate)
    }

    private var weekPicker: some View {
        let calendar = appCalendar
        let weekday = calendar.component(.weekday, from: selectedDate)
        let mondayOffset = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: calendar.startOfDay(for: selectedDate)) ?? selectedDate
        return VStack(spacing: 12) {
            HStack {
                Text("Твоя неделя").font(.subheadline.bold())
                Spacer()
                Button("Сегодня") { selectedDate = .now }.font(.caption.bold()).frame(minHeight: 44)
            }
            ViewThatFits(in: .horizontal) {
                weekDays(from: monday)
                ScrollView(.horizontal, showsIndicators: false) { weekDays(from: monday) }
            }
        }
    }

    private func weekDays(from monday: Date) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let date = appCalendar.date(byAdding: .day, value: offset, to: monday) ?? monday
                let selected = appCalendar.isDate(date, inSameDayAs: selectedDate)
                Button { selectedDate = date } label: {
                    VStack(spacing: 8) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated))).font(.caption2)
                        Text(date.formatted(.dateTime.day())).font(.subheadline.bold()).monospacedDigit()
                        Circle().fill(appCalendar.isDateInToday(date) ? (selected ? Color.white : AppTheme.violet) : .clear).frame(width: 4, height: 4)
                    }.frame(minWidth: 44, maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(selected ? AppTheme.violet : AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(ScalePressStyle())
                    .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func lessonCard(_ lesson: Lesson, now: Date) -> some View {
        let items = Array(homeworkFor(lesson).prefix(2))
        let canWriteHomework = lessonHasStarted(lesson, now: now)
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

            if canWriteHomework {
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
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.82), value: canWriteHomework)
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
    private func lessonHasStarted(_ lesson: Lesson, now: Date) -> Bool {
        guard Calendar.current.isDateInToday(selectedDate), let start = dateTime(lesson.startsAt, on: selectedDate) else { return false }
        return now >= start
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
    @State private var automaticDeadline = true

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
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Срок выполнения", systemImage: "calendar.badge.clock").font(.headline)
                                Spacer()
                                Toggle("Автоматически", isOn: $automaticDeadline).labelsHidden().tint(AppTheme.violet)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(automaticDeadline ? "Автоматический срок" : "Выбран вручную").font(.caption.bold()).foregroundStyle(automaticDeadline ? AppTheme.mint : AppTheme.violet)
                                Text(dueDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute())).font(.title3.bold())
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background((automaticDeadline ? AppTheme.mint : AppTheme.violet).opacity(0.09), in: RoundedRectangle(cornerRadius: 14))

                            Divider()
                            Text("Выбери дату в календаре").font(.subheadline.bold())
                            DatePicker("Дата", selection: manualDueDate, displayedComponents: .date)
                                .datePickerStyle(.graphical).labelsHidden().tint(AppTheme.violet)
                            HStack {
                                Label("Время", systemImage: "clock")
                                Spacer()
                                DatePicker("Время", selection: manualDueDate, displayedComponents: .hourAndMinute).labelsHidden().datePickerStyle(.compact).tint(AppTheme.violet)
                            }.font(.subheadline.bold())
                            Text("По умолчанию срок совпадает с началом следующего урока. Изменение даты или времени отключит автоматический режим.").font(.caption).foregroundStyle(.secondary)
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
            .onChange(of: automaticDeadline) { _, enabled in if enabled { withAnimation(.snappy) { dueDate = nextLessonDate } } }
        }
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var manualDueDate: Binding<Date> {
        Binding(get: { dueDate }, set: { value in dueDate = value; automaticDeadline = false })
    }
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

struct DayOverrideView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var selection = 0
    @State private var note = ""

    private let choices = [(0, "По обычному расписанию"), (2, "Как в понедельник"), (3, "Как во вторник"), (4, "Как в среду"), (5, "Как в четверг"), (6, "Как в пятницу"), (7, "Как в субботу"), (1, "Как в воскресенье"), (-1, "Без уроков")]

    var body: some View {
        NavigationStack {
            Form {
                Section { LabeledContent("Дата", value: date.formatted(date: .long, time: .omitted)) }
                Section("Как учимся в этот день") {
                    Picker("Расписание", selection: $selection) {
                        ForEach(choices, id: \.0) { choice in Text(choice.1).tag(choice.0) }
                    }.pickerStyle(.inline).labelsHidden()
                }
                Section {
                    TextField("Например: перенос из-за праздника", text: $note, axis: .vertical).lineLimit(2...4)
                } header: {
                    Text("Комментарий")
                } footer: {
                    Text("Замена действует только для выбранной даты. Например, в субботу можно включить расписание понедельника, не меняя остальные недели.")
                }
            }
            .navigationTitle("Замена расписания").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() } }
            }
            .onAppear { if let current = store.override(on: date) { selection = current.sourceWeekday ?? -1; note = current.note } }
        }
    }

    private func save() {
        if selection == 0 { store.clearScheduleOverride(on: date) }
        else { store.setScheduleOverride(on: date, sourceWeekday: selection == -1 ? nil : selection, note: note.trimmingCharacters(in: .whitespacesAndNewlines)) }
        dismiss()
    }
}
