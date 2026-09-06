import SwiftUI

struct PlannerView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                PremiumTitle(eyebrow: "Меньше суеты", title: "Твой следующий шаг", icon: "sparkles")
                if let item = PlannerLogic.nextTask(store.homework, plans: store.planner.plans) {
                    NavigationLink { TaskStepsView(homeworkID: item.id) } label: {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Что делать сейчас?", systemImage: "arrow.right.circle.fill").foregroundStyle(AppTheme.violet)
                                Text(item.text).font(.title3.bold()).foregroundStyle(.primary)
                                Text("\(item.lessonTitle) · срок \(item.dueDate.formatted(date: .abbreviated, time: .omitted))").foregroundStyle(.secondary)
                                Text("Ближайший срок сдачи. При равном сроке учитываем важность и время.").font(.caption).foregroundStyle(.secondary)
                                Label("Оценка времени: \((store.planner.plans[item.id.uuidString] ?? TaskPlan()).minutes) мин", systemImage: "timer").font(.subheadline.bold())
                            }
                        }
                    }.buttonStyle(ScalePressStyle())
                } else { ContentUnavailableView("Всё выполнено", systemImage: "checkmark.seal", description: Text("Можно отдохнуть или добавить новое задание.")) }
                NavigationLink { TomorrowView() } label: { DashboardAction(title: "Подготовиться к завтра", subtitle: "Уроки, домашка и вещи", symbol: "backpack.fill", color: AppTheme.blue) }.buttonStyle(ScalePressStyle())
                NavigationLink { GradeGoalView() } label: { DashboardAction(title: "Цели по предметам", subtitle: "Какие оценки помогут достичь цели", symbol: "scope", color: AppTheme.violet) }.buttonStyle(ScalePressStyle())
                NavigationLink { PlannerTrashView() } label: { DashboardAction(title: "Корзина", subtitle: "\(store.planner.trash.count) записей · можно восстановить", symbol: "arrow.uturn.backward", color: AppTheme.blue) }.buttonStyle(ScalePressStyle())
                SoftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(store.saveMessage, systemImage: "internaldrive.fill").font(.subheadline)
                        Text("Задания и план доступны без интернета. Это локальное сохранение, не облачная резервная копия.").font(.caption).foregroundStyle(.secondary)
                        Button("Сохранить сейчас") { store.flushSaves() }.buttonStyle(.bordered)
                    }
                }
            }.padding()
        }.background { AnimatedAppBackground() }.navigationTitle("Мой план")
    }
}

struct TaskStepsView: View {
    @EnvironmentObject private var store: AppStore
    let homeworkID: UUID
    @State private var newStep = ""
    private var item: Homework? { store.homework.first { $0.id == homeworkID } }
    private var plan: TaskPlan { store.planner.plans[homeworkID.uuidString] ?? TaskPlan() }
    private func update(_ change: (inout TaskPlan) -> Void) {
        var value = plan; change(&value); store.planner.plans[homeworkID.uuidString] = value
    }
    var body: some View {
        Form {
            if let item {
                Section {
                    Text(item.text).font(.title3.bold())
                    Text(item.lessonTitle).foregroundStyle(.secondary)
                    Stepper("Осталось примерно \(plan.minutes) мин", value: Binding(get: { plan.minutes }, set: { minutes in update { $0.minutes = minutes } }), in: 5...480, step: 5)
                    Toggle("Важное задание", isOn: Binding(get: { plan.important }, set: { important in update { $0.important = important } }))
                }
                Section("Маленькие шаги · \(plan.steps.filter(\.done).count)/\(plan.steps.count)") {
                    ForEach(plan.steps) { step in
                        Button { update { value in if let index = value.steps.firstIndex(where: { $0.id == step.id }) { value.steps[index].done.toggle() } } } label: {
                            Label(step.title, systemImage: step.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.done ? AppTheme.violet : Color.primary).strikethrough(step.done).padding(.vertical, 6)
                        }.accessibilityHint("Переключить выполнение шага")
                    }.onDelete { offsets in update { $0.steps.remove(atOffsets: offsets) } }
                    TextField("Например: решить первые три задачи", text: $newStep, axis: .vertical)
                    Button("Добавить шаг") {
                        let title = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
                        update { $0.steps.append(TaskStep(title: title)) }; newStep = ""
                    }.disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if plan.steps.isEmpty {
                        Button("Добавить шаблон из трёх шагов") { update { $0.steps = ["Разобраться в условии", "Выполнить основную часть", "Проверить результат"].map { TaskStep(title: $0) } } }
                    }
                }
                Section {
                    Button(item.isDone ? "Вернуть в работу" : "Завершить всё задание") {
                        if let index = store.homework.firstIndex(where: { $0.id == homeworkID }) { store.homework[index].isDone.toggle(); store.flushSaves() }
                    }
                    Text("Шаги сохраняются отдельно. Завершение шагов не отмечает автоматически всё задание.").font(.caption).foregroundStyle(.secondary)
                }
            } else { Text("Задание удалено. Его можно восстановить из корзины.") }
        }.navigationTitle("По шагам").scrollContentBackground(.hidden).background { AnimatedAppBackground() }
    }
}

struct TomorrowView: View {
    @EnvironmentObject private var store: AppStore
    @State private var thing = ""
    private var date: Date { Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now }
    private var lessons: [Lesson] { store.lessons(on: date) }
    private var tasks: [Homework] {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date
        return store.homework.filter { !$0.isDone && $0.dueDate < end }.sorted { $0.dueDate < $1.dueDate }
    }
    var body: some View {
        List {
            Section {
                Text(date.formatted(date: .complete, time: .omitted)).font(.headline)
                Text(lessons.first.map { "Первый урок в \($0.startsAt)" } ?? "Уроков нет — можно выдохнуть").foregroundStyle(.secondary)
            }
            Section("Уроки") {
                ForEach(lessons) { lesson in
                    HStack { Text(lesson.title); Spacer(); Text("\(lesson.startsAt)–\(lesson.endsAt)").font(.caption.monospacedDigit()) }
                }
            }
            Section("Не забудь выполнить · включая просроченные") {
                ForEach(tasks) { task in NavigationLink { TaskStepsView(homeworkID: task.id) } label: { VStack(alignment: .leading) { Text(task.text); Text(task.lessonTitle).font(.caption).foregroundStyle(.secondary) } } }
                if tasks.isEmpty { Label("Домашка под контролем", systemImage: "checkmark.circle") }
            }
            Section("Собрать с собой") {
                ForEach(store.planner.bag.filter { Calendar.current.isDate($0.day, inSameDayAs: date) }) { item in
                    Toggle(item.title, isOn: Binding(get: { store.planner.bag.first { $0.id == item.id }?.packed ?? false }, set: { value in if let index = store.planner.bag.firstIndex(where: { $0.id == item.id }) { store.planner.bag[index].packed = value } }))
                        .swipeActions { Button("Удалить", role: .destructive) { store.planner.bag.removeAll { $0.id == item.id } } }
                }
                TextField("Добавить вещь", text: $thing)
                Button("Добавить") { store.planner.bag.append(BagItem(title: thing.trimmingCharacters(in: .whitespacesAndNewlines), day: date)); thing = "" }.disabled(thing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Подсказать по расписанию") {
                    let suggestions = ["Пенал"] + Array(Set(lessons.map { $0.title.localizedCaseInsensitiveContains("физкультур") ? "Спортивная форма" : "Тетрадь: \($0.title)" })).sorted()
                    let existing = Set(store.planner.bag.filter { Calendar.current.isDate($0.day, inSameDayAs: date) }.map(\.title))
                    store.planner.bag.append(contentsOf: suggestions.filter { !existing.contains($0) }.map { BagItem(title: $0, day: date) })
                }
            }
        }.navigationTitle("Завтра").scrollContentBackground(.hidden).background { AnimatedAppBackground() }
    }
}

struct GradeGoalView: View {
    @EnvironmentObject private var store: AppStore
    @State private var subject = ""
    @State private var count = 3
    @State private var weight = 1
    private var subjects: [String] { Array(Set(store.grades.map(\.subject) + store.lessons.map(\.title))).sorted() }
    private var target: Double { store.planner.goals[subject] ?? 8 }
    var body: some View {
        Form {
            Section("Цель по десятибалльной системе") {
                Picker("Предмет", selection: $subject) { Text("Выбери предмет").tag(""); ForEach(subjects, id: \.self) { Text($0).tag($0) } }
                if !subject.isEmpty {
                    Stepper("Средний балл: \(target, specifier: "%.1f")", value: Binding(get: { target }, set: { store.planner.goals[subject] = $0 }), in: 1...10, step: 0.5)
                    Stepper("Следующих оценок: \(count)", value: $count, in: 1...20)
                    Stepper("Вес каждой: \(weight)", value: $weight, in: 1...10)
                }
            }
            if !subject.isEmpty {
                let required = PlannerLogic.requiredGrade(grades: store.grades.filter { $0.subject == subject }, target: target, count: count, weight: weight)
                Section("Расчёт") {
                    Text(required > 10 ? "За выбранное число оценок цель пока недостижима. Увеличь их количество." : required <= 1 ? "Достаточно любых положительных оценок при выбранных условиях." : "Нужен средний балл следующих оценок не ниже \(String(format: "%.2f", ceil(required * 100) / 100)).").font(.headline)
                    Text("Учитываются все записанные оценки этого предмета и их веса. Это математический прогноз, а не обещание итоговой оценки учителя.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("Цель по предмету").scrollContentBackground(.hidden).background { AnimatedAppBackground() }
    }
}

struct PlannerTrashView: View {
    @EnvironmentObject private var store: AppStore
    @State private var deleting: TrashEntry?
    @State private var restoring: TrashEntry?
    var body: some View {
        List {
            Text("Записи хранятся здесь, пока ты не удалишь их окончательно.").font(.caption).foregroundStyle(.secondary)
            ForEach(store.planner.trash.sorted { $0.date > $1.date }) { entry in
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.title).font(.headline)
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    HStack { Button("Восстановить") { restoring = entry }; Spacer(); Button("Удалить навсегда", role: .destructive) { deleting = entry } }.buttonStyle(.bordered)
                }.padding(.vertical, 6)
            }
        }.navigationTitle("Корзина")
            .confirmationDialog("Восстановить запись?", isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }), presenting: restoring) { entry in Button("Восстановить") { store.restore(entry) } } message: { entry in Text(entry.lessons == nil ? "Задание вернётся в список." : "Текущее расписание будет заменено и сохранено в корзине.") }
            .confirmationDialog("Удалить без возможности восстановления?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { entry in Button("Удалить навсегда", role: .destructive) { store.planner.trash.removeAll { $0.id == entry.id } } }
    }
}
