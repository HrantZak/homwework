import Foundation

struct TaskStep: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var done = false
}

struct TaskPlan: Codable, Sendable {
    var minutes = 20
    var important = false
    var steps: [TaskStep] = []
}

struct BagItem: Codable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var day: Date
    var packed = false
}

struct TrashEntry: Codable, Identifiable, Sendable {
    var id = UUID()
    var date = Date()
    var homework: Homework? = nil
    var lessons: [Lesson]? = nil
    var title: String
}

struct PlannerData: Codable, Sendable {
    var plans: [String: TaskPlan] = [:]
    var bag: [BagItem] = []
    var goals: [String: Double] = [:]
    var trash: [TrashEntry] = []
    var acceptedMessages: [String] = []
}

enum PlannerLogic {
    static func nextTask(_ items: [Homework], plans: [String: TaskPlan]) -> Homework? {
        items.filter { !$0.isDone }.min { a, b in
            // Deadline first; importance and shortest estimate break ties within a day.
            let aDay = Calendar.current.startOfDay(for: a.dueDate)
            let bDay = Calendar.current.startOfDay(for: b.dueDate)
            if aDay != bDay { return aDay < bDay }
            let ap = plans[a.id.uuidString] ?? TaskPlan()
            let bp = plans[b.id.uuidString] ?? TaskPlan()
            if ap.important != bp.important { return ap.important }
            if ap.minutes != bp.minutes { return ap.minutes < bp.minutes }
            return a.id.uuidString < b.id.uuidString
        }
    }

    static func requiredGrade(grades: [Grade], target: Double, count: Int, weight: Int) -> Double {
        let valid = grades.filter { (1...10).contains($0.value) }
        let totalWeight = valid.reduce(0) { $0 + max(1, $1.weight ?? 1) }
        let sum = valid.reduce(0) { $0 + $1.value * max(1, $1.weight ?? 1) }
        let addedWeight = max(1, count) * max(1, weight)
        return (target * Double(totalWeight + addedWeight) - Double(sum)) / Double(addedWeight)
    }

    static func validSchedule(_ items: [Lesson]) -> Bool {
        func minute(_ value: String) -> Int? {
            let parts = value.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
            return parts[0] * 60 + parts[1]
        }
        guard !items.isEmpty, items.count <= 100, Set(items.map(\.id)).count == items.count else { return false }
        return items.allSatisfy {
            guard (1...7).contains($0.weekday), $0.order > 0, !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let start = minute($0.startsAt), let end = minute($0.endsAt) else { return false }
            return start < end
        }
    }
}
