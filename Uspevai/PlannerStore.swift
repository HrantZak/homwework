import Foundation

extension AppStore {
    func archiveSchedule() {
        guard !lessons.isEmpty else { return }
        planner.trash.append(TrashEntry(lessons: lessons, title: "Расписание · \(lessons.count) уроков"))
    }

    func deleteHomework(ids: [UUID]) {
        let ids = Set(ids)
        planner.trash.append(contentsOf: homework.filter { ids.contains($0.id) }.map {
            TrashEntry(homework: $0, title: $0.text)
        })
        homework.removeAll { ids.contains($0.id) }
        flushSaves()
    }

    func restore(_ entry: TrashEntry) {
        if let item = entry.homework, !homework.contains(where: { $0.id == item.id }) { homework.append(item) }
        if let snapshot = entry.lessons {
            archiveSchedule()
            lessons = snapshot
            refreshNotifications()
        }
        planner.trash.removeAll { $0.id == entry.id }
        flushSaves()
    }

    func acceptSchedule(_ incoming: [Lesson], messageID: String) {
        guard PlannerLogic.validSchedule(incoming), !planner.acceptedMessages.contains(messageID) else { return }
        replaceLessons(incoming)
        planner.acceptedMessages.append(messageID)
        flushSaves()
    }
}
