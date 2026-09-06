import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 5))!
let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
let before = calendar.date(byAdding: .day, value: -2, to: today)!
let grades = [Grade(subject: "Math", value: 10, date: today, weight: 3), Grade(subject: "Math", value: 6, date: yesterday, weight: 1)]
let snapshot = StudySnapshot(grades: grades)
assert(snapshot.average == 9 && snapshot.totalWeight == 4, "Weighted statistics")
assert(snapshot.excellent == 1 && snapshot.gradeCounts[10] == 1, "Distribution")
assert(StudySnapshot().average == 0 && StudySnapshot().completed == 0, "Empty statistics")
let invalidWeight = StudySnapshot(grades: [Grade(subject: "Math", value: 8, weight: 0)])
assert(invalidWeight.average == 8 && invalidWeight.totalWeight == 1, "Legacy weight fallback")
var streak = StudySnapshot()
streak.activityDays = [today, yesterday, before]
assert(streak.streak(on: today, calendar: calendar) == 3, "Consecutive activity")
streak.activityDays = [yesterday, before]
assert(streak.streak(on: today, calendar: calendar) == 2, "Yesterday grace")
streak.activityDays = [before]
assert(streak.streak(on: today, calendar: calendar) == 0, "Broken streak")
let wallet = MarketWallet(productIDs: ["ring-1", "font-2"], spent: 272)
let restored = try JSONDecoder().decode(MarketWallet.self, from: JSONEncoder().encode(wallet))
assert(restored.productIDs == wallet.productIDs && restored.spent == wallet.spent, "Wallet record round trip")
let legacy = """
{"id":"00000000-0000-0000-0000-000000000001","lessonTitle":"Math","text":"Read","dueDate":0,"isDone":false}
"""
let legacyHomework = try JSONDecoder().decode(Homework.self, from: Data(legacy.utf8))
assert(legacyHomework.createdAt == nil, "Legacy homework")
print("Study statistics, streak, wallet record and legacy data checks passed.")

let plannerEarly = Homework(lessonTitle: "Math", text: "First", dueDate: Date(timeIntervalSince1970: 1000))
let plannerLater = Homework(lessonTitle: "Math", text: "Later", dueDate: Date(timeIntervalSince1970: 900000))
assert(PlannerLogic.nextTask([plannerLater, plannerEarly], plans: [:])?.id == plannerEarly.id)
var plannerDone = plannerEarly
plannerDone.isDone = true
assert(PlannerLogic.nextTask([plannerDone], plans: [:]) == nil)
let plannerRequired = PlannerLogic.requiredGrade(grades: [Grade(subject: "Math", value: 6, weight: 2)], target: 8, count: 2, weight: 1)
assert(plannerRequired == 10, "Weighted target calculation")
assert(PlannerLogic.requiredGrade(grades: [], target: 8, count: 3, weight: 1) == 8)
assert(PlannerLogic.requiredGrade(grades: [Grade(subject: "Math", value: 1)], target: 10, count: 1, weight: 1) > 10)
let plannerLesson = Lesson(weekday: 2, order: 1, title: "Math", startsAt: "09:00", endsAt: "09:40")
assert(PlannerLogic.validSchedule([plannerLesson]))
assert(!PlannerLogic.validSchedule([plannerLesson, plannerLesson]), "Reject duplicate IDs")
var plannerInvalid = plannerLesson
plannerInvalid.endsAt = "08:00"
assert(!PlannerLogic.validSchedule([plannerInvalid]))
var plannerRecord = PlannerData()
plannerRecord.plans[plannerEarly.id.uuidString] = TaskPlan(minutes: 35, important: true, steps: [TaskStep(title: "Read", done: true)])
plannerRecord.trash = [TrashEntry(homework: plannerEarly, title: "Saved")]
let plannerRestored = try JSONDecoder().decode(PlannerData.self, from: JSONEncoder().encode(plannerRecord))
assert(plannerRestored.plans[plannerEarly.id.uuidString]?.steps.first?.done == true)
assert(plannerRestored.trash.first?.homework?.id == plannerEarly.id)
print("Planner ranking, weighted targets, schedule validation and persistence checks passed.")
