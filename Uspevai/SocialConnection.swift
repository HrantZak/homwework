import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
enum SocialConnection {
    private static var signIn: Task<String, Error>?

    static func userID() async throws -> String {
        FirebaseBootstrap.configure()
        guard FirebaseBootstrap.isConfigured else { throw ConnectionError.missingConfiguration }
        if let uid = Auth.auth().currentUser?.uid { return uid }
        if let signIn { return try await signIn.value }
        let task = Task { try await Auth.auth().signInAnonymously().user.uid }
        signIn = task
        defer { signIn = nil }
        return try await task.value
    }

    static func errorText(_ error: Error) -> String {
        let value = error as NSError
        if value.domain == FirestoreErrorDomain {
            switch value.code {
            case 7: return "Firebase запретил доступ. Владелец приложения должен опубликовать актуальный firestore.rules в Firebase → Firestore → Rules. Затем нажмите «Повторить»."
            case 14, 4: return "Не удалось связаться с сервером. Проверьте интернет и повторите. Текст сообщения сохранён."
            case 16: return "Не удалось войти. Проверьте, что Anonymous включён в Firebase Authentication."
            default: break
            }
        }
        return error.localizedDescription
    }

    enum ConnectionError: LocalizedError {
        case missingConfiguration, selfChat, oversized
        var errorDescription: String? {
            switch self {
            case .missingConfiguration: return "В сборке отсутствует настройка Firebase."
            case .selfChat: return "Это ваш профиль. Выберите другого пользователя."
            case .oversized: return "Слишком большой текст или вложение. Уменьшите объём и повторите."
            }
        }
    }
}
