import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var heroMoves = false
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
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [AppTheme.violet, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Circle().fill(.white.opacity(0.13)).frame(width: 180).offset(x: heroMoves ? 210 : 250, y: heroMoves ? -35 : -70)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(timeline.date.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.subheadline).opacity(0.8)
                            Text(today.isEmpty ? "Сегодня можно выдохнуть" : "Сегодня \(lessonCountText(today.count))").font(.system(size: 29, weight: .bold, design: .rounded))
                            Text("Всё важное — в одном месте").opacity(0.82)
                        }.foregroundStyle(.white).padding(24)
                    }.frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).shadow(color: AppTheme.violet.opacity(0.18), radius: 12, y: 7).onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) { heroMoves = true } }

                    if !today.isEmpty { dayProgress(completed: completed, total: today.count) }
                    if let active = activeLesson(in: today, now: timeline.date) { activeLessonCard(active) }
                    if let homework = openHomework.first { homeworkFocus(homework) }

                    HStack {
                        Text("Твой день").font(.title2.bold())
                        Spacer()
                        if let next { Text("Далее · \(next.startsAt)").font(.caption.bold()).foregroundStyle(AppTheme.violet) }
                    }
                    if today.isEmpty { ContentUnavailableView("Уроков нет", systemImage: "sun.max", description: Text("Посмотри задания или отдохни")) }
                    ForEach(today) { lesson in LessonRow(lesson: lesson) }
                    }.padding()
                }.background { AnimatedAppBackground() }
            }.navigationTitle("Успевай")
                .sheet(item: $homeworkLesson) { lesson in SmartHomeworkEntryView(lesson: lesson, lessonDate: .now).presentationDetents([.large]) }
        }
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
                Image(systemName: "waveform.circle.fill").font(.title).symbolEffect(.pulse).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 3) { Text("Сейчас идёт урок").font(.caption.bold()).opacity(0.8); Text(lesson.title).font(.headline); Text("Можно уже записывать домашнее задание").font(.caption).opacity(0.8) }
                Spacer(); Image(systemName: "square.and.pencil").font(.title3.bold())
            }.padding(17).foregroundStyle(.white).background(LinearGradient(colors: [AppTheme.coral, AppTheme.violet], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 21))
        }.buttonStyle(ScalePressStyle())
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
        }.animation(.spring(response: 0.45, dampingFraction: 0.82), value: completed)
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
            HStack(spacing: 15) {
                VStack { Text(lesson.startsAt).font(.headline); Text(lesson.endsAt).font(.caption).foregroundStyle(.secondary) }
                Capsule().fill(AppTheme.violet.gradient).frame(width: 5, height: 46)
                VStack(alignment: .leading, spacing: 4) { Text(lesson.title).font(.headline); if !lesson.teacher.isEmpty { Text(lesson.teacher).font(.caption).foregroundStyle(.secondary) } }
                Spacer()
                Text("\(lesson.order)").font(.caption.bold()).foregroundStyle(AppTheme.violet).padding(8).background(AppTheme.violet.opacity(0.12), in: Circle())
            }
        }.transition(.move(edge: .bottom).combined(with: .opacity)).contentShape(RoundedRectangle(cornerRadius: 25))
    }
}
