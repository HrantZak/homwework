import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

struct PublicStudentProfile: Identifiable, Equatable {
    let id: String
    let ownerID: String
    let name: String
    let bio: String
    let streak: Int
    let level: Int
    let accentIndex: Int
    let pinnedAchievementIDs: [String]
    let updatedAt: Date
}

enum FirebaseBootstrap {
    static var isConfigured: Bool { FirebaseApp.app() != nil }

    static func configure() {
        guard FirebaseApp.app() == nil,
              let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else { return }
        FirebaseApp.configure(options: options)
    }
}

@MainActor
final class FirebaseProfileService: ObservableObject {
    @Published private(set) var accountReady = false
    @Published private(set) var isWorking = false
    @Published private(set) var friends: [PublicStudentProfile] = []
    @Published var foundProfile: PublicStudentProfile?
    @Published var message = ""

    private let defaults = UserDefaults.standard
    private var database: Firestore? { FirebaseBootstrap.isConfigured ? Firestore.firestore() : nil }

    var profileCode: String {
        if let saved = defaults.string(forKey: "communityProfileCode") { return saved }
        let code = Self.makeCode()
        defaults.set(code, forKey: "communityProfileCode")
        return code
    }

    private var friendCodes: [String] {
        get { defaults.stringArray(forKey: "communityFriendCodes") ?? [] }
        set { defaults.set(newValue, forKey: "communityFriendCodes") }
    }

    func connect() async {
        guard FirebaseBootstrap.isConfigured else {
            accountReady = false
            message = "Добавьте GoogleService-Info.plist в проект"
            return
        }
        do {
            if Auth.auth().currentUser == nil { _ = try await Auth.auth().signInAnonymously() }
            accountReady = Auth.auth().currentUser != nil
            message = accountReady ? "Firebase подключён" : "Не удалось войти"
            if accountReady { await loadFriends() }
        } catch { accountReady = false; message = friendly(error) }
    }

    func publish(name: String, bio: String, streak: Int, level: Int, accentIndex: Int, pinnedAchievementIDs: [String], isPublic: Bool) async {
        guard let database, let userID = Auth.auth().currentUser?.uid else { message = "Firebase ещё не подключён"; return }
        isWorking = true
        defer { isWorking = false }
        let data: [String: Any] = [
            "ownerID": userID, "code": profileCode, "name": name, "bio": bio,
            "streak": streak, "level": level, "accentIndex": accentIndex,
            "pinnedAchievements": Array(pinnedAchievementIDs.prefix(3)),
            "isPublic": isPublic, "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            try await database.collection("profiles").document(profileCode).setData(data, merge: true)
            defaults.set(isPublic, forKey: "communityPublished")
            message = isPublic ? "Профиль опубликован и обновлён" : "Профиль скрыт"
        } catch { message = friendly(error) }
    }

    func search(code rawCode: String) async {
        let code = Self.normalized(rawCode)
        guard code.count == 8 else { message = "Введите восьмизначный код"; foundProfile = nil; return }
        guard let database else { message = "Firebase ещё не подключён"; return }
        isWorking = true
        defer { isWorking = false }
        do {
            let snapshot = try await database.collection("profiles").document(code).getDocument()
            guard snapshot.exists, let profile = Self.profile(from: snapshot), snapshot.data()?["isPublic"] as? Bool == true else {
                foundProfile = nil; message = "Пользователь не найден или скрыл профиль"; return
            }
            foundProfile = profile; message = "Профиль найден"
        } catch { foundProfile = nil; message = friendly(error) }
    }

    func addFoundProfile() async {
        guard let foundProfile else { return }
        guard foundProfile.ownerID != Auth.auth().currentUser?.uid else { message = "Это ваш собственный профиль"; return }
        var codes = friendCodes
        if !codes.contains(foundProfile.id) { codes.append(foundProfile.id); friendCodes = codes }
        message = "\(foundProfile.name) добавлен в друзья"
        await loadFriends()
    }

    func removeFriend(_ profile: PublicStudentProfile) {
        friendCodes.removeAll { $0 == profile.id }
        friends.removeAll { $0.id == profile.id }
        message = "Пользователь удалён из друзей"
    }

    func loadFriends() async {
        guard let database else { return }
        isWorking = true
        defer { isWorking = false }
        var loaded: [PublicStudentProfile] = []
        var availableCodes: [String] = []
        for code in friendCodes {
            guard let snapshot = try? await database.collection("profiles").document(code).getDocument(),
                  snapshot.data()?["isPublic"] as? Bool == true,
                  let profile = Self.profile(from: snapshot) else { continue }
            loaded.append(profile); availableCodes.append(code)
        }
        friends = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        friendCodes = availableCodes
    }

    private static func profile(from snapshot: DocumentSnapshot) -> PublicStudentProfile? {
        guard let data = snapshot.data(), let name = data["name"] as? String, let ownerID = data["ownerID"] as? String else { return nil }
        return PublicStudentProfile(id: snapshot.documentID, ownerID: ownerID, name: name, bio: data["bio"] as? String ?? "", streak: number(data["streak"], fallback: 0), level: number(data["level"], fallback: 1), accentIndex: number(data["accentIndex"], fallback: 0), pinnedAchievementIDs: data["pinnedAchievements"] as? [String] ?? [], updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast)
    }

    private static func number(_ value: Any?, fallback: Int) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return fallback
    }

    private func friendly(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return "Нет подключения к интернету" }
        return "Ошибка Firebase: \(error.localizedDescription)"
    }

    private static func makeCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).compactMap { _ in alphabet.randomElement() })
    }

    static func normalized(_ value: String) -> String { value.uppercased().filter { $0.isLetter || $0.isNumber } }
}
