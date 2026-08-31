import Foundation

struct Lesson: Identifiable, Codable, Hashable {
    var id = UUID()
    var weekday: Int
    var order: Int
    var title: String
    var teacher: String = ""
    var startsAt: String
    var endsAt: String
}

struct Homework: Identifiable, Codable, Hashable {
    var id = UUID()
    var lessonTitle: String
    var text: String
    var dueDate: Date
    var isDone = false
}

struct Grade: Identifiable, Codable, Hashable {
    var id = UUID(); var subject: String; var value: Int; var date = Date(); var note = ""; var lessonID: UUID? = nil
}

struct Attendance: Identifiable, Codable, Hashable {
    var id = UUID(); var subject: String; var date = Date(); var wasPresent = true
}

struct Exam: Identifiable, Codable, Hashable {
    var id = UUID(); var title: String; var subject: String; var date: Date; var room = ""
}

struct SchoolNote: Identifiable, Codable, Hashable {
    var id = UUID(); var title: String; var text: String; var createdAt = Date(); var isPinned = false
}

enum SeedData {
    static let times = [("09:00", "09:45"), ("09:55", "10:40"), ("10:50", "11:35"), ("11:45", "12:30")]
    static let titles: [[String]] = [
        ["История", "Операционные системы", "Русский язык"],
        ["Архитектура компьютера", "Основы математического анализа", "Безопасность и первая помощь", "Английский язык"],
        ["Применение элементов алгоритмов", "Операционные системы", "Армянский язык и культура речи"],
        ["Архитектура компьютера", "Основы математического анализа", "Применение элементов алгоритмов", "История"],
        ["Физкультура", "Основы экологии и природопользования", "Английский язык"]
    ]
    static var lessons: [Lesson] {
        titles.enumerated().flatMap { day, subjects in
            subjects.enumerated().map { index, subject in
                Lesson(weekday: day + 2, order: index + 1, title: subject,
                       startsAt: times[index].0, endsAt: times[index].1)
            }
        }
    }
}
