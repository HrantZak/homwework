import Foundation

/// Built when study data changes, not for every achievement cell or animation frame.
struct StudySnapshot {
    var completed = 0
    var excellent = 0
    var present = 0
    var average = 0.0
    var totalWeight = 0
    var gradeCounts = Array(repeating: 0, count: 11)
    var activityDays = Set<Date>()

    init(homework: [Homework] = [], grades: [Grade] = [], attendance: [Attendance] = []) {
        let calendar = Calendar.current
        for item in homework where item.isDone {
            completed += 1
            if let date = item.createdAt { activityDays.insert(calendar.startOfDay(for: date)) }
        }
        var points = 0.0
        for grade in grades {
            let weight = max(1, grade.weight ?? 1)
            totalWeight += weight
            points += Double(grade.value) * Double(weight)
            if grade.value >= 9 { excellent += 1 }
            if (1...10).contains(grade.value) { gradeCounts[grade.value] += 1 }
            activityDays.insert(calendar.startOfDay(for: grade.date))
        }
        average = totalWeight == 0 ? 0 : points / Double(totalWeight)
        for entry in attendance where entry.wasPresent {
            present += 1
            activityDays.insert(calendar.startOfDay(for: entry.date))
        }
    }

    func streak(on now: Date = Date(), calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: now)
        if !activityDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while activityDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
