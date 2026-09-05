import Combine
import FirebaseFirestore
import Foundation

struct ChatSummary: Identifiable {
    let id: String
    let person: PublicStudentProfile
    let preview: String
    let updatedAt: Date
}

@MainActor
final class ChatInbox: ObservableObject {
    @Published private(set) var chats: [ChatSummary] = []
    @Published private(set) var error = ""
    @Published private(set) var isLoading = false
    private var listener: ListenerRegistration?
    private var session = UUID()
    deinit { listener?.remove() }

    func start() async {
        stop()
        let token = session
        isLoading = true
        error = ""
        do {
            let uid = try await SocialConnection.userID()
            guard token == session, !Task.isCancelled else { return }
            listener = Firestore.firestore().collection("chats")
                .whereField("participants", arrayContains: uid).limit(to: 100)
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self, token == self.session else { return }
                        self.isLoading = false
                        if let error { self.error = SocialConnection.errorText(error); return }
                        self.chats = (snapshot?.documents ?? []).compactMap { document -> ChatSummary? in
                            let data = document.data()
                            guard let members = data["participants"] as? [String],
                                  let other = members.first(where: { $0 != uid }) else { return nil }
                            let names = data["participantNames"] as? [String: String] ?? [:]
                            let codes = data["participantCodes"] as? [String: String] ?? [:]
                            let date = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                            let person = PublicStudentProfile(id: codes[other] ?? "", ownerID: other, name: names[other] ?? "Участник", bio: "", streak: 0, level: 1, accentIndex: 0, pinnedAchievementIDs: [], title: "", ringID: "", fontID: "", gradeAverage: 0, gradeCount: 0, excellentCount: 0, homeworkPercent: 0, updatedAt: date)
                            return ChatSummary(id: document.documentID, person: person, preview: data["lastMessage"] as? String ?? "Начните разговор", updatedAt: date)
                        }.sorted { $0.updatedAt > $1.updatedAt }
                    }
                }
        } catch {
            guard token == session else { return }
            isLoading = false; self.error = SocialConnection.errorText(error)
        }
    }

    func stop() { session = UUID(); listener?.remove(); listener = nil; isLoading = false }
}
