import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class AppStore: ObservableObject {
    @Published var planner: PlannerData { didSet { persist(planner, key: "planner.v1") } }
    @Published private(set) var saveMessage = "Сохранено на устройстве"
    @Published var lessons: [Lesson] { didSet { scheduleSave(lessons, key: "lessons") } }
    @Published var homework: [Homework] { didSet { scheduleSave(homework, key: "homework"); refreshStudySnapshot() } }
    @Published var grades: [Grade] { didSet { scheduleSave(grades, key: "grades"); refreshStudySnapshot() } }
    @Published var attendance: [Attendance] { didSet { scheduleSave(attendance, key: "attendance"); refreshStudySnapshot() } }
    @Published var exams: [Exam] { didSet { scheduleSave(exams, key: "exams") } }
    @Published var notes: [SchoolNote] { didSet { scheduleSave(notes, key: "notes") } }
    @Published var scheduleOverrides: [ScheduleOverride] { didSet { scheduleSave(scheduleOverrides, key: "scheduleOverrides") } }
    @Published var termEnd: Date { didSet { defaults.set(termEnd, forKey: "termEnd") } }
    @Published var remindersEnabled: Bool { didSet { defaults.set(remindersEnabled, forKey: "reminders"); scheduleNotifications() } }
    @Published var darkMode: Bool { didSet { defaults.set(darkMode, forKey: "darkMode") } }
    @Published var studentName: String { didSet { defaults.set(studentName, forKey: "studentName") } }
    @Published var profileBio: String { didSet { defaults.set(profileBio, forKey: "profileBio") } }
    @Published var accentIndex: Int { didSet { defaults.set(accentIndex, forKey: "accentIndex") } }
    @Published var pinnedAchievementIDs: [String] { didSet { scheduleSave(pinnedAchievementIDs, key: "pinnedAchievementIDs") } }
    @Published var purchasedMarketIDs: [String] { didSet { scheduleSave(purchasedMarketIDs, key: "purchasedMarketIDs"); ownedMarketIDs = Set(purchasedMarketIDs) } }
    @Published var equippedRingID: String { didSet { defaults.set(equippedRingID, forKey: "equippedRingID") } }
    @Published var equippedFontID: String { didSet { defaults.set(equippedFontID, forKey: "equippedFontID") } }
    @Published var equippedTitleID: String { didSet { defaults.set(equippedTitleID, forKey: "equippedTitleID") } }
    @Published var spentCoins: Int { didSet { defaults.set(spentCoins, forKey: "spentCoins") } }
    @Published var adminCoins: Int { didSet { defaults.set(adminCoins, forKey: "adminCoins") } }

    @Published private(set) var ownedMarketIDs = Set<String>()
    @Published private(set) var study = StudySnapshot()

    private func refreshStudySnapshot() { study = StudySnapshot(homework: homework, grades: grades, attendance: attendance) }

    private let defaults = UserDefaults.standard
    private var pendingSaves: [String: Task<Void, Never>] = [:]

    init() {
        planner = Self.load(PlannerData.self, key: "planner.v1") ?? PlannerData()
        lessons = Self.load([Lesson].self, key: "lessons") ?? SeedData.lessons
        homework = Self.load([Homework].self, key: "homework") ?? []
        grades = Self.load([Grade].self, key: "grades") ?? []
        attendance = Self.load([Attendance].self, key: "attendance") ?? []
        exams = Self.load([Exam].self, key: "exams") ?? []
        notes = Self.load([SchoolNote].self, key: "notes") ?? []
        scheduleOverrides = Self.load([ScheduleOverride].self, key: "scheduleOverrides") ?? []
        termEnd = defaults.object(forKey: "termEnd") as? Date ?? Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 26))!
        remindersEnabled = defaults.object(forKey: "reminders") as? Bool ?? true
        darkMode = defaults.bool(forKey: "darkMode")
        studentName = defaults.string(forKey: "studentName") ?? "Ученик"
        profileBio = defaults.string(forKey: "profileBio") ?? "Иду к цели шаг за шагом"
        accentIndex = defaults.integer(forKey: "accentIndex")
        pinnedAchievementIDs = Self.load([String].self, key: "pinnedAchievementIDs") ?? []
        purchasedMarketIDs = Self.load([String].self, key: "purchasedMarketIDs") ?? []
        equippedRingID = defaults.string(forKey: "equippedRingID") ?? ""
        equippedFontID = defaults.string(forKey: "equippedFontID") ?? ""
        equippedTitleID = defaults.string(forKey: "equippedTitleID") ?? ""
        spentCoins = defaults.integer(forKey: "spentCoins")
        adminCoins = defaults.integer(forKey: "adminCoins")
        if let wallet = Self.load(MarketWallet.self, key: "marketWallet") {
            purchasedMarketIDs = wallet.productIDs
            spentCoins = wallet.spent
        }
        if !defaults.bool(forKey: "migratedToTenPointScale") {
            grades = grades.map { old in var updated = old; updated.value = min(10, old.value * 2); return updated }
            if let data = try? JSONEncoder().encode(grades) { defaults.set(data, forKey: "grades") }
            defaults.set(true, forKey: "migratedToTenPointScale")
        }
        refreshStudySnapshot()
        ownedMarketIDs = Set(purchasedMarketIDs)
        if defaults.data(forKey: "lessons") == nil { persist(lessons, key: "lessons") }
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        scheduleNotifications()
    }

    func addHomework(for lesson: Lesson, text: String, dueDate: Date) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        homework.append(Homework(lessonTitle: lesson.title, text: text, dueDate: dueDate, lessonID: lesson.id, createdAt: Date()))
    }

    func replaceLessons(_ imported: [Lesson]) {
        guard !imported.isEmpty else { return }
        archiveSchedule()
        lessons = imported.sorted { ($0.weekday, $0.order) < ($1.weekday, $1.order) }
        scheduleNotifications()
    }

    func refreshNotifications() { scheduleNotifications() }

    func lessons(on date: Date) -> [Lesson] {
        let day = Calendar.current.component(.weekday, from: date)
        let override = scheduleOverrides.last { Calendar.current.isDate($0.date, inSameDayAs: date) }
        guard let source = override?.sourceWeekday else {
            if override != nil { return [] }
            return lessons.filter { $0.weekday == day }.sorted { $0.order < $1.order }
        }
        return lessons.filter { $0.weekday == source }.sorted { $0.order < $1.order }
    }

    func setScheduleOverride(on date: Date, sourceWeekday: Int?, note: String = "") {
        scheduleOverrides.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        scheduleOverrides.append(ScheduleOverride(date: Calendar.current.startOfDay(for: date), sourceWeekday: sourceWeekday, note: note))
    }

    func clearScheduleOverride(on date: Date) {
        scheduleOverrides.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func override(on date: Date) -> ScheduleOverride? {
        scheduleOverrides.last { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var earnedCoins: Int {
        study.completed * 12 + grades.count * 6 + study.excellent * 4
    }

    var coinBalance: Int { max(0, earnedCoins + adminCoins - spentCoins) }

    @discardableResult
    func buy(_ product: MarketProduct) -> Bool {
        guard let product = MarketCatalog.product(id: product.id), !purchasedMarketIDs.contains(product.id), product.price >= 0, coinBalance >= product.price else { return false }
        spentCoins += product.price
        purchasedMarketIDs.append(product.id)
        // One persisted record keeps ownership and spending together after restart.
        if let data = try? JSONEncoder().encode(MarketWallet(productIDs: purchasedMarketIDs, spent: spentCoins)) { defaults.set(data, forKey: "marketWallet") }
        equip(product)
        return true
    }

    func equip(_ product: MarketProduct) {
        guard let product = MarketCatalog.product(id: product.id), purchasedMarketIDs.contains(product.id) || product.price == 0 else { return }
        switch product.kind {
        case .ring: equippedRingID = product.id
        case .font: equippedFontID = product.id
        case .title: equippedTitleID = product.id
        }
    }

    var profileTitle: String { MarketCatalog.product(id: equippedTitleID)?.name ?? "Ученик нового поколения" }
    var activeAppFont: Font {
        guard let product = MarketCatalog.product(id: equippedFontID) else { return .body }
        return .custom(MarketCatalog.fontFamily(for: product), size: 17, relativeTo: .body)
    }
    func activeFont(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        guard let product = MarketCatalog.product(id: equippedFontID) else { return .system(size: size) }
        return .custom(MarketCatalog.fontFamily(for: product), size: size, relativeTo: style)
    }

    /// Finish pending writes before iOS can suspend the process.
    func flushSaves() {
        pendingSaves.values.forEach { $0.cancel() }
        pendingSaves.removeAll()
        persist(lessons, key: "lessons")
        persist(homework, key: "homework")
        persist(grades, key: "grades")
        persist(attendance, key: "attendance")
        persist(exams, key: "exams")
        persist(notes, key: "notes")
        persist(scheduleOverrides, key: "scheduleOverrides")
        persist(pinnedAchievementIDs, key: "pinnedAchievementIDs")
        persist(purchasedMarketIDs, key: "purchasedMarketIDs")
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
            saveMessage = pendingSaves.isEmpty ? "Сохранено на устройстве" : "Сохраняю…"
        } catch { saveMessage = "Не удалось сохранить. Не закрывай приложение и повтори сохранение." }
    }

    private func scheduleSave<T: Encodable & Sendable>(_ value: T, key: String) {
        saveMessage = "Сохраняю…"
        pendingSaves[key]?.cancel()
        pendingSaves[key] = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let data = await Task.detached(priority: .utility) {
                try? JSONEncoder().encode(value)
            }.value
            guard !Task.isCancelled else { return }
            guard let data else { self.saveMessage = "Ошибка сохранения. Нажми «Сохранить сейчас» в разделе «Мой план»."; return }
            UserDefaults.standard.set(data, forKey: key)
            self.pendingSaves.removeValue(forKey: key)
            self.saveMessage = self.pendingSaves.isEmpty ? "Сохранено на устройстве" : "Сохраняю…"
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
            let bits = lesson.startsAt.split(separator: ":").compactMap { Int($0) }
            guard bits.count == 2 else { continue }
            var date = DateComponents()
            date.weekday = lesson.weekday
            date.hour = bits[0]
            date.minute = bits[1]
            let content = UNMutableNotificationContent()
            content.title = "Урок начался"
            content.body = "Можно записывать домашнее задание по предмету «\(lesson.title)»"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            center.add(UNNotificationRequest(identifier: "lesson-\(lesson.id)", content: content, trigger: trigger))
        }
    }
}
