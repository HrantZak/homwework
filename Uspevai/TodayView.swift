import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAdd = false
    @State private var showFocus = false
    @State private var homeworkLesson: Lesson?
    private var openHomework: [Homework] {
        store.homework.filter { !$0.isDone }.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let today = lessons(on: timeline.date)
                let completed = completedLessons(in: today, now: timeline.date)
                let next = nextLesson(in: today, now: timeline.date)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                    dashboardHero(date: timeline.date, completed: completed, total: today.count, next: next)
                    NavigationLink { PlannerView() } label: {
                        DashboardAction(title: "Мой план", subtitle: "Что делать сейчас · завтра · цели", symbol: "list.bullet.clipboard.fill", color: AppTheme.violet)
                    }.buttonStyle(ScalePressStyle())
                    HStack(spacing: 12) {
                        Button { showAdd = true } label: {
                            DashboardAction(title: "Записать", subtitle: "Новое задание", symbol: "plus", color: AppTheme.violet)
                        }
                        Button { showFocus = true } label: {
                            DashboardAction(title: "Сфокусироваться", subtitle: "Таймер работы", symbol: "timer", color: AppTheme.blue)
                        }
                    }.buttonStyle(ScalePressStyle())
                    if let active = activeLesson(in: today, now: timeline.date) { activeLessonCard(active) }
                    if let homework = openHomework.first { homeworkFocus(homework) }

                    SectionHeader(title: "Твой день", subtitle: today.isEmpty ? "Свободный день" : "Расписание и прогресс", symbol: "calendar.day.timeline.left")
                    if today.isEmpty { ContentUnavailableView("Уроков нет", systemImage: "sun.max", description: Text("Посмотри задания или отдохни")) }
                    ForEach(today) { lesson in LessonRow(lesson: lesson) }
                    }.padding()
                }.background { AnimatedAppBackground() }
            }.navigationTitle("Сегодня")
                .toolbar { NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Настройки") }
                .sheet(item: $homeworkLesson) { lesson in SmartHomeworkEntryView(lesson: lesson, lessonDate: .now).presentationDetents([.large]) }
                .sheet(isPresented: $showAdd) { AddHomeworkView() }
                .sheet(isPresented: $showFocus) { FocusSessionSheet() }
        }
    }

    private func dashboardHero(date: Date, completed: Int, total: Int, next: Lesson?) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label(date.formatted(.dateTime.day().month(.wide)), systemImage: "sun.max.fill")
                Spacer()
                Text(date.formatted(.dateTime.weekday(.abbreviated))).textCase(.uppercase)
            }.font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    heroHeadline(total: total, completed: completed)
                    Spacer(minLength: 0)
                    dailyRing(completed: completed, total: total)
                }
                VStack(alignment: .leading, spacing: 20) {
                    heroHeadline(total: total, completed: completed)
                    dailyRing(completed: completed, total: total)
                }
            }
            HStack(spacing: 8) {
                heroMetric("\(openHomework.count)", "заданий", "book.closed.fill")
                heroMetric(next?.startsAt ?? "—", next == nil ? "уроков больше нет" : "ближайший урок", "clock.fill")
            }
        }.foregroundStyle(.white).padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { OrbitBackdrop() }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .revealOnAppear()
    }

    private func heroHeadline(total: Int, completed: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ТВОЙ РИТМ").font(.caption.bold()).tracking(2).foregroundStyle(AppTheme.mint)
            Text(total == 0 ? "Время для себя" : completed == total ? "Ты справился!" : "Шаг за шагом.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            Text(total == 0 ? "Отдохни или займись любимым делом." : "Сегодня \(lessonCountText(total)). Всё получится.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dailyRing(completed: Int, total: Int) -> some View {
        ZStack {
            ProgressRing(progress: Double(completed) / Double(max(1, total)), color: AppTheme.mint, size: 88, lineWidth: 7)
            VStack(spacing: 2) {
                Text("\(completed)").font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
                Text("из \(total)").font(.caption).foregroundStyle(.white.opacity(0.8))
            }
        }.padding(5).accessibilityElement(children: .ignore).accessibilityLabel("Пройдено уроков: \(completed) из \(total)")
    }

    private func lessons(on date: Date) -> [Lesson] {
        store.lessons(on: date)
    }

    private func completedLessons(in lessons: [Lesson], now: Date) -> Int {
        lessons.filter { lesson in guard let end = time(on: now, value: lesson.endsAt) else { return false }; return end <= now }.count
    }

    private func nextLesson(in lessons: [Lesson], now: Date) -> Lesson? {
        lessons.first { lesson in guard let end = time(on: now, value: lesson.endsAt) else { return false }; return end > now }
    }

    private func activeLesson(in lessons: [Lesson], now: Date) -> Lesson? {
        lessons.first { lesson in
            guard let start = time(on: now, value: lesson.startsAt), let end = time(on: now, value: lesson.endsAt) else { return false }
            return now >= start && now < end
        }
    }

    private func activeLessonCard(_ lesson: Lesson) -> some View {
        Button { homeworkLesson = lesson } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.and.pencil").font(.title).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 3) { Text("Сейчас идёт урок").font(.caption.bold()).opacity(0.8); Text(lesson.title).font(.headline); Text("Можно уже записывать домашнее задание").font(.caption).opacity(0.8) }
                Spacer(); Image(systemName: "square.and.pencil").font(.title3.bold())
            }.padding(20).foregroundStyle(.white).background(AppTheme.deepViolet, in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(ScalePressStyle())
    }

    private func heroMetric(_ value: String, _ title: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) { Image(systemName: symbol).font(.caption2); Text(value).font(.subheadline.bold()).monospacedDigit() }
            Text(title).font(.caption).opacity(0.8)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
    }

    private func lessonCountText(_ count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        let word = remainder10 == 1 && remainder100 != 11 ? "урок" : (2...4).contains(remainder10) && !(12...14).contains(remainder100) ? "урока" : "уроков"
        return "\(count) \(word)"
    }

    private func dayProgress(completed: Int, total: Int) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Label(completed == total ? "Учебный день завершён" : "Прогресс дня", systemImage: completed == total ? "checkmark.seal.fill" : "clock.fill").font(.headline)
                    Spacer()
                    Text("\(completed) из \(total)").font(.subheadline.bold()).foregroundStyle(completed == total ? AppTheme.mint : AppTheme.violet).contentTransition(.numericText())
                }
                ProgressView(value: Double(completed), total: Double(max(1, total))).tint(completed == total ? AppTheme.mint : AppTheme.violet)
            }
        }.animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: completed)
    }

    private func homeworkFocus(_ item: Homework) -> some View {
        SoftCard {
            HStack(spacing: 13) {
                Image(systemName: Calendar.current.isDateInToday(item.dueDate) ? "exclamationmark.circle.fill" : "list.clipboard.fill")
                    .font(.title2).foregroundStyle(Calendar.current.isDateInToday(item.dueDate) ? AppTheme.coral : AppTheme.violet)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ближайшее задание").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(item.text).font(.subheadline.bold()).lineLimit(2)
                    Text("\(item.lessonTitle) · \(dueText(item.dueDate))").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func dueText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "сегодня" }
        if Calendar.current.isDateInTomorrow(date) { return "завтра" }
        if date < Calendar.current.startOfDay(for: .now) { return "срок прошёл" }
        return "до \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private func time(on date: Date, value: String) -> Date? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date)
    }
}

struct LessonRow: View {
    let lesson: Lesson
    var body: some View {
        SoftCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(lessonColor.opacity(0.12))
                    Image(systemName: lessonSymbol).font(.title3.bold()).foregroundStyle(lessonColor)
                }.frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 4) { Text(lesson.title).font(.headline); if !lesson.teacher.isEmpty { Text(lesson.teacher).font(.caption).foregroundStyle(.secondary) } }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text(lesson.startsAt).font(.subheadline.monospacedDigit().bold()); Text(lesson.endsAt).font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
            }
        }.transition(.move(edge: .bottom).combined(with: .opacity)).contentShape(RoundedRectangle(cornerRadius: 25))
    }
    private var lessonColor: Color { [AppTheme.violet, AppTheme.blue, AppTheme.mint, AppTheme.coral, AppTheme.gold][abs(lesson.order - 1) % 5] }
    private var lessonSymbol: String { ["book.closed.fill", "function", "globe.europe.africa.fill", "text.book.closed.fill", "atom"][abs(lesson.order - 1) % 5] }
}
