import Foundation
import UserNotifications

@MainActor
final class AppStore: ObservableObject {
    @Published var lessons: [Lesson] { didSet { save(); scheduleNotifications() } }
    @Published var homework: [Homework] { didSet { save() } }
    @Published var remindersEnabled: Bool { didSet { defaults.set(remindersEnabled, forKey: "reminders"); scheduleNotifications() } }
    @Published var darkMode: Bool { didSet { defaults.set(darkMode, forKey: "darkMode") } }

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        lessons = Self.load([Lesson].self, key: "lessons") ?? SeedData.lessons
        homework = Self.load([Homework].self, key: "homework") ?? []
        remindersEnabled = defaults.object(forKey: "reminders") as? Bool ?? true
        darkMode = defaults.bool(forKey: "darkMode")
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
    }

    private func save() {
        if let data = try? encoder.encode(lessons) { defaults.set(data, forKey: "lessons") }
        if let data = try? encoder.encode(homework) { defaults.set(data, forKey: "homework") }
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
