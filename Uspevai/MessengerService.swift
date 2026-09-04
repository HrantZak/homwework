import FirebaseAuth
import FirebaseFirestore
import Foundation

enum StudyMessageKind: String, Codable, Sendable { case text, schedule, grades, analytics }

struct StudyMessage: Identifiable, Equatable, Sendable {
    let id: String
    let senderID: String
    let kind: StudyMessageKind
    let text: String
    let payload: String
    let sentAt: Date
    let isPending: Bool
}

struct SharedAnalytics: Codable, Sendable {
    let average: Double
    let gradeCount: Int
    let excellentCount: Int
    let completedHomework: Int
    let homeworkCount: Int
}

@MainActor
final class MessengerService: ObservableObject {
    @Published private(set) var messages: [StudyMessage] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage = ""
    private var listener: ListenerRegistration?
    private var database: Firestore? { FirebaseBootstrap.isConfigured ? Firestore.firestore() : nil }
    var currentUserID: String { Auth.auth().currentUser?.uid ?? "" }

    deinit { listener?.remove() }

    func listen(to profile: PublicStudentProfile, senderName: String) async {
        stop()
        guard let database, !currentUserID.isEmpty else { errorMessage = "Сначала подключите профиль к Firebase"; return }
        do { try await prepareChat(database: database, profile: profile, senderName: senderName) }
        catch { errorMessage = error.localizedDescription; return }
        isLoading = true
        listener = database.collection("chats").document(chatID(with: profile.ownerID)).collection("messages")
            .order(by: "sentAt", descending: true).limit(to: 60)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error { self.errorMessage = error.localizedDescription; return }
                    self.messages = Array((snapshot?.documents ?? []).compactMap(Self.message).reversed())
                }
            }
    }

    func stop() { listener?.remove(); listener = nil; messages = []; isLoading = false }

    func sendText(_ value: String, to profile: PublicStudentProfile, senderName: String) async {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        await send(kind: .text, text: String(clean.prefix(2000)), payload: "", to: profile, senderName: senderName)
    }

    func shareSchedule(_ lessons: [Lesson], to profile: PublicStudentProfile, senderName: String) async {
        let sorted = lessons.sorted { ($0.weekday, $0.order) < ($1.weekday, $1.order) }
        guard let data = try? JSONEncoder().encode(Array(sorted.prefix(50))), let payload = String(data: data, encoding: .utf8) else { return }
        await send(kind: .schedule, text: "Моё расписание", payload: payload, to: profile, senderName: senderName)
    }

    func shareGrades(_ grades: [Grade], to profile: PublicStudentProfile, senderName: String) async {
        let recent = grades.sorted { $0.date > $1.date }.prefix(30)
        guard let data = try? JSONEncoder().encode(Array(recent)), let payload = String(data: data, encoding: .utf8) else { return }
        await send(kind: .grades, text: "Мои последние оценки", payload: payload, to: profile, senderName: senderName)
    }

    func shareAnalytics(grades: [Grade], homework: [Homework], to profile: PublicStudentProfile, senderName: String) async {
        let analytics = SharedAnalytics(average: grades.isEmpty ? 0 : Double(grades.map(\.value).reduce(0, +)) / Double(grades.count), gradeCount: grades.count, excellentCount: grades.filter { $0.value >= 9 }.count, completedHomework: homework.filter(\.isDone).count, homeworkCount: homework.count)
        guard let data = try? JSONEncoder().encode(analytics), let payload = String(data: data, encoding: .utf8) else { return }
        await send(kind: .analytics, text: "Моя учебная аналитика", payload: payload, to: profile, senderName: senderName)
    }

    private func send(kind: StudyMessageKind, text: String, payload: String, to profile: PublicStudentProfile, senderName: String) async {
        guard let database, !currentUserID.isEmpty else { errorMessage = "Нет подключения к Firebase"; return }
        let id = chatID(with: profile.ownerID)
        let chat = database.collection("chats").document(id)
        do {
            try await prepareChat(database: database, profile: profile, senderName: senderName)
            try await chat.collection("messages").addDocument(data: ["senderID": currentUserID, "kind": kind.rawValue, "text": text, "payload": String(payload.prefix(80_000)), "sentAt": FieldValue.serverTimestamp()])
        } catch { errorMessage = error.localizedDescription }
    }

    private func prepareChat(database: Firestore, profile: PublicStudentProfile, senderName: String) async throws {
        try await database.collection("chats").document(chatID(with: profile.ownerID)).setData([
            "participants": [currentUserID, profile.ownerID].sorted(),
            "participantNames": [currentUserID: senderName, profile.ownerID: profile.name],
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func chatID(with otherID: String) -> String { [currentUserID, otherID].sorted().joined(separator: "_") }
    private static func message(_ snapshot: QueryDocumentSnapshot) -> StudyMessage? {
        let data = snapshot.data()
        guard let senderID = data["senderID"] as? String, let rawKind = data["kind"] as? String, let kind = StudyMessageKind(rawValue: rawKind) else { return nil }
        return StudyMessage(id: snapshot.documentID, senderID: senderID, kind: kind, text: data["text"] as? String ?? "", payload: data["payload"] as? String ?? "", sentAt: (data["sentAt"] as? Timestamp)?.dateValue() ?? .now, isPending: snapshot.metadata.hasPendingWrites)
    }
}
