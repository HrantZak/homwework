import Combine
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
    @Published private(set) var isSending = false
    @Published private(set) var isReady = false
    @Published var errorMessage = ""
    private var listener: ListenerRegistration?
    private var session = UUID()
    private var database: Firestore? { FirebaseBootstrap.isConfigured ? Firestore.firestore() : nil }
    var currentUserID: String { FirebaseBootstrap.isConfigured ? Auth.auth().currentUser?.uid ?? "" : "" }

    deinit { listener?.remove() }

    func listen(to profile: PublicStudentProfile, senderName: String) async {
        stop()
        let token = session
        errorMessage = ""
        isLoading = true
        do {
            _ = try await SocialConnection.userID()
            guard !profile.ownerID.isEmpty, profile.ownerID != currentUserID else { throw SocialConnection.ConnectionError.selfChat }
            guard let database else { throw SocialConnection.ConnectionError.missingConfiguration }
            try await prepareChat(database: database, profile: profile, senderName: senderName)
        } catch {
            guard session == token else { return }
            isLoading = false; errorMessage = SocialConnection.errorText(error); return
        }
        guard session == token, !Task.isCancelled, let database else { return }
        isReady = true
        listener = database.collection("chats").document(chatID(with: profile.ownerID)).collection("messages")
            .order(by: "sentAt", descending: true).limit(to: 60)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.session == token else { return }
                    self.isLoading = false
                    if let error { self.isReady = false; self.errorMessage = SocialConnection.errorText(error); return }
                    self.messages = Array((snapshot?.documents ?? []).compactMap(Self.message).reversed())
                }
            }
    }

    func stop() { session = UUID(); listener?.remove(); listener = nil; isReady = false; isLoading = false }

    func sendText(_ value: String, to profile: PublicStudentProfile, senderName: String) async -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        return await send(kind: .text, text: clean, payload: "", to: profile, senderName: senderName)
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

    @discardableResult
    private func send(kind: StudyMessageKind, text: String, payload: String, to profile: PublicStudentProfile, senderName: String) async -> Bool {
        guard !isSending else { return false }
        guard let database, isReady, !currentUserID.isEmpty else { errorMessage = "Чат ещё не подключён. Нажмите «Повторить подключение»."; return false }
        guard text.utf8.count <= 2000, payload.utf8.count <= 80000 else { errorMessage = SocialConnection.ConnectionError.oversized.localizedDescription; return false }
        isSending = true
        defer { isSending = false }
        errorMessage = ""
        let id = chatID(with: profile.ownerID)
        let chat = database.collection("chats").document(id)
        do {
            let batch = database.batch()
            batch.setData(["senderID": currentUserID, "kind": kind.rawValue, "text": text, "payload": payload, "sentAt": FieldValue.serverTimestamp()], forDocument: chat.collection("messages").document())
            batch.updateData(["updatedAt": FieldValue.serverTimestamp(), "lastMessage": String(text.prefix(120))], forDocument: chat)
            try await batch.commit()
            return true
        } catch { errorMessage = SocialConnection.errorText(error); return false }
    }

    private func prepareChat(database: Firestore, profile: PublicStudentProfile, senderName: String) async throws {
        try await database.collection("chats").document(chatID(with: profile.ownerID)).setData([
            "participants": [currentUserID, profile.ownerID].sorted(),
            "participantNames": [currentUserID: senderName, profile.ownerID: profile.name],
            "participantCodes": [currentUserID: UserDefaults.standard.string(forKey: "communityProfileCode") ?? "", profile.ownerID: profile.id]
        ], merge: true)
    }

    private func chatID(with otherID: String) -> String { [currentUserID, otherID].sorted().joined(separator: "_") }
    private static func message(_ snapshot: QueryDocumentSnapshot) -> StudyMessage? {
        let data = snapshot.data()
        guard let senderID = data["senderID"] as? String, let rawKind = data["kind"] as? String, let kind = StudyMessageKind(rawValue: rawKind) else { return nil }
        return StudyMessage(id: snapshot.documentID, senderID: senderID, kind: kind, text: data["text"] as? String ?? "", payload: data["payload"] as? String ?? "", sentAt: (data["sentAt"] as? Timestamp)?.dateValue() ?? .now, isPending: snapshot.metadata.hasPendingWrites)
    }
}
