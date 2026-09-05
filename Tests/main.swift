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
