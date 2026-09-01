import Foundation
import UserNotifications

@MainActor
final class AppStore: ObservableObject {
    @Published var lessons: [Lesson] { didSet { scheduleSave(lessons, key: "lessons") } }
    @Published var homework: [Homework] { didSet { scheduleSave(homework, key: "homework") } }
    @Published var grades: [Grade] { didSet { scheduleSave(grades, key: "grades") } }
    @Published var attendance: [Attendance] { didSet { scheduleSave(attendance, key: "attendance") } }
    @Published var exams: [Exam] { didSet { scheduleSave(exams, key: "exams") } }
    @Published var notes: [SchoolNote] { didSet { scheduleSave(notes, key: "notes") } }
    @Published var termEnd: Date { didSet { defaults.set(termEnd, forKey: "termEnd") } }
    @Published var remindersEnabled: Bool { didSet { defaults.set(remindersEnabled, forKey: "reminders"); scheduleNotifications() } }
    @Published var darkMode: Bool { didSet { defaults.set(darkMode, forKey: "darkMode") } }

    private let defaults = UserDefaults.standard
    private var pendingSaves: [String: Task<Void, Never>] = [:]

    init() {
        lessons = Self.load([Lesson].self, key: "lessons") ?? SeedData.lessons
        homework = Self.load([Homework].self, key: "homework") ?? []
        grades = Self.load([Grade].self, key: "grades") ?? []
        attendance = Self.load([Attendance].self, key: "attendance") ?? []
        exams = Self.load([Exam].self, key: "exams") ?? []
        notes = Self.load([SchoolNote].self, key: "notes") ?? []
        termEnd = defaults.object(forKey: "termEnd") as? Date ?? Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 26))!
        remindersEnabled = defaults.object(forKey: "reminders") as? Bool ?? true
        darkMode = defaults.bool(forKey: "darkMode")
        if !defaults.bool(forKey: "migratedToTenPointScale") {
            grades = grades.map { old in var updated = old; updated.value = min(10, old.value * 2); return updated }
            defaults.set(true, forKey: "migratedToTenPointScale")
        }
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        scheduleNotifications()
    }

    func addHomework(for lesson: Lesson, text: String, dueDate: Date) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        homework.append(Homework(lessonTitle: lesson.title, text: text, dueDate: dueDate))
    }

    func replaceLessons(_ imported: [Lesson]) {
        guard !imported.isEmpty else { return }
        lessons = imported.sorted { ($0.weekday, $0.order) < ($1.weekday, $1.order) }
        scheduleNotifications()
    }

    func refreshNotifications() { scheduleNotifications() }

    private func scheduleSave<T: Encodable & Sendable>(_ value: T, key: String) {
        pendingSaves[key]?.cancel()
        pendingSaves[key] = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let data = await Task.detached(priority: .utility) {
                try? JSONEncoder().encode(value)
            }.value
            guard !Task.isCancelled, let data else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard remindersEnabled else { return }
        for lesson in lessons {
            let bits = lesson.endsAt.split(separator: ":").compactMap { Int($0) }
            guard bits.count == 2 else { continue }
            var date = DateComponents()
            date.weekday = lesson.weekday
            date.hour = bits[0]
            date.minute = bits[1]
            let content = UNMutableNotificationContent()
            content.title = "Урок закончился"
            content.body = "Запиши домашнее задание по предмету «\(lesson.title)»"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            center.add(UNNotificationRequest(identifier: "lesson-\(lesson.id)", content: content, trigger: trigger))
        }
    }
}
