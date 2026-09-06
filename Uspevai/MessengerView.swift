import Foundation
import SwiftUI

struct MessengerView: View {
    let friends: [PublicStudentProfile]
    @StateObject private var inbox = ChatInbox()
    @State private var query = ""
    private var newFriends: [PublicStudentProfile] {
        friends.filter { friend in !inbox.chats.contains { $0.person.ownerID == friend.ownerID } && matches(friend.name) }
    }
    private func matches(_ text: String) -> Bool { query.isEmpty || text.localizedCaseInsensitiveContains(query) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Сообщения", subtitle: "Входящие и ваши диалоги", symbol: "message.fill")
            TextField("Поиск по имени", text: $query).textFieldStyle(.roundedBorder)
            if inbox.isLoading { ProgressView("Загружаю диалоги…") }
            if !inbox.error.isEmpty {
                Text(inbox.error).font(.caption).foregroundStyle(.orange)
                Button("Повторить") { Task { await inbox.start() } }
            }
            ForEach(inbox.chats.filter { matches($0.person.name) }) { chat in
                NavigationLink { StudyChatView(friend: friends.first { $0.ownerID == chat.person.ownerID } ?? chat.person) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(AppTheme.violet)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.person.name).font(.headline)
                            Text(chat.preview).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
            ForEach(newFriends) { friend in
                NavigationLink { StudyChatView(friend: friend) } label: {
                    HStack(spacing: 13) {
                        AvatarRingView(ringID: friend.ringID.isEmpty ? "ring-0" : friend.ringID, size: 50, animated: false) { Text(initials(friend.name)).font(.headline.bold()).foregroundStyle(.white).frame(width: 39, height: 39).background(AppTheme.violet.gradient, in: Circle()) }
                        VStack(alignment: .leading, spacing: 3) { Text(friend.name).font(.headline); Text("Открыть диалог").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "message.badge.fill").foregroundStyle(AppTheme.violet)
                    }.padding(15).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(ScalePressStyle())
            }
            if friends.isEmpty && inbox.chats.isEmpty && !inbox.isLoading && inbox.error.isEmpty { ContentUnavailableView("Чатов пока нет", systemImage: "bubble.left.and.bubble.right", description: Text("Добавьте друга или дождитесь первого входящего сообщения")) }
        }.task { await inbox.start() }.onDisappear { inbox.stop() }
    }
    private func initials(_ name: String) -> String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
}

struct StudyChatView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var messenger = MessengerService()
    @StateObject private var contacts = FirebaseProfileService()
    @State private var draft = ""
    @State private var showShareConfirmation: ShareKind?
    @Environment(\.scenePhase) private var scenePhase
    let friend: PublicStudentProfile

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    privacyBanner
                    Label(messenger.isOnline ? "Сеть доступна" : "Нет сети · сообщения остаются в очереди", systemImage: messenger.isOnline ? "wifi" : "wifi.slash").font(.caption).foregroundStyle(.secondary)
                    ForEach(messenger.outbox.filter { queued in !messenger.messages.contains { $0.id == queued.id } }) { queued in
                        HStack { Spacer(); VStack(alignment: .trailing, spacing: 5) { Text(queued.text); Label("Ожидает отправки", systemImage: "clock").font(.caption) }.padding(14).background(AppTheme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 18)) }
                    }
                    if !messenger.outbox.isEmpty { Button("Повторить отправку · \(messenger.outbox.count)") { Task { await messenger.retryOutbox() } }.disabled(messenger.isSending || !messenger.isOnline) }
                    if !contacts.message.isEmpty { Text(contacts.message).font(.caption).foregroundStyle(.secondary) }
                    if !messenger.isReady && !messenger.isLoading {
                        Button("Повторить подключение") { Task { await messenger.listen(to: friend, senderName: store.studentName) } }.buttonStyle(.bordered)
                    }
                    if messenger.isSending { ProgressView("Ожидаю подтверждение сервера…").font(.caption) }
                    if messenger.isLoading { ProgressView().padding() }
                    ForEach(messenger.messages) { message in MessageBubble(message: message, isMine: message.senderID == messenger.currentUserID).equatable().id(message.id) }
                    if messenger.messages.isEmpty && !messenger.isLoading { ContentUnavailableView("Начните разговор", systemImage: "hand.wave.fill", description: Text("Можно отправить сообщение или учебную карточку")) }
                }.padding()
            }
            .background { AnimatedAppBackground() }
            .onChange(of: messenger.messages.last?.id) { _, id in if let id { proxy.scrollTo(id, anchor: .bottom) } }
        }
        .navigationTitle(friend.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(contacts.isFriend(friend) ? "В друзьях" : "Добавить") { Task { await contacts.add(profile: friend) } }
                    .disabled(contacts.isFriend(friend))
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .task {
            draft = UserDefaults.standard.string(forKey: "chatDraft-\(friend.ownerID)") ?? ""
            await messenger.listen(to: friend, senderName: store.studentName)
        }
        .onDisappear { UserDefaults.standard.set(draft, forKey: "chatDraft-\(friend.ownerID)"); messenger.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await messenger.listen(to: friend, senderName: store.studentName) } }
            else { UserDefaults.standard.set(draft, forKey: "chatDraft-\(friend.ownerID)"); messenger.stop() }
        }
        .confirmationDialog("Что отправить?", isPresented: Binding(get: { showShareConfirmation != nil }, set: { if !$0 { showShareConfirmation = nil } }), presenting: showShareConfirmation) { kind in
            Button(kind.actionTitle) { Task { await share(kind) } }
            Button("Отмена", role: .cancel) {}
        } message: { kind in Text(kind.warning) }
        .alert("Сообщения", isPresented: Binding(get: { !messenger.errorMessage.isEmpty }, set: { if !$0 { messenger.errorMessage = "" } })) { Button("Хорошо") { messenger.errorMessage = "" } } message: { Text(messenger.errorMessage) }
    }

    private var privacyBanner: some View { Label("Только вы и \(friend.name) видите этот чат", systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 8).background(.thinMaterial, in: Capsule()) }
    private var composer: some View {
        HStack(spacing: 10) {
            Menu { Button { showShareConfirmation = .homework } label: { Label("Задания", systemImage: "checklist") }; Button { showShareConfirmation = .schedule } label: { Label("Расписание", systemImage: "calendar") }; Button { showShareConfirmation = .grades } label: { Label("Оценки", systemImage: "star.fill") }; Button { showShareConfirmation = .analytics } label: { Label("Круг аналитики", systemImage: "chart.pie.fill") } } label: { Image(systemName: "plus").font(.headline).frame(width: 42, height: 42).background(AppTheme.violet.opacity(0.12), in: Circle()) }.accessibilityLabel("Прикрепить")
            TextField("Сообщение", text: $draft, axis: .vertical).lineLimit(1...4).padding(.horizontal, 14).padding(.vertical, 11).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            Button { send() } label: { Image(systemName: "arrow.up").font(.headline.bold()).foregroundStyle(.white).frame(width: 42, height: 42).background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : AppTheme.violet, in: Circle()) }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Отправить")
        }.padding(.horizontal).padding(.vertical, 9).background(.ultraThinMaterial)
    }
    private func send() {
        let value = draft
        UserDefaults.standard.set(value, forKey: "chatDraft-\(friend.ownerID)")
        Task {
            if await messenger.sendText(value, to: friend, senderName: store.studentName), draft == value {
                draft = ""; UserDefaults.standard.removeObject(forKey: "chatDraft-\(friend.ownerID)")
            }
        }
    }
    private func share(_ kind: ShareKind) async { switch kind { case .homework: await messenger.shareHomework(store.homework, to: friend, senderName: store.studentName); case .schedule: await messenger.shareSchedule(store.lessons, to: friend, senderName: store.studentName); case .grades: await messenger.shareGrades(store.grades, to: friend, senderName: store.studentName); case .analytics: await messenger.shareAnalytics(grades: store.grades, homework: store.homework, to: friend, senderName: store.studentName) } }
}

private enum ShareKind: String, Identifiable { case schedule, grades, analytics, homework; var id: String { rawValue }; var actionTitle: String { switch self { case .homework: "Отправить задания"; case .schedule: "Отправить расписание"; case .grades: "Отправить оценки"; case .analytics: "Отправить аналитику" } }; var warning: String { switch self { case .homework: "Друг увидит до 50 активных заданий, предметы и сроки. Он сможет принять их в свой список."; case .schedule: "Друг увидит предметы, дни и время уроков."; case .grades: "Друг увидит последние 30 оценок и названия предметов."; case .analytics: "Друг увидит средний балл и общую статистику заданий." } } }

private struct MessageBubble: View, Equatable {
    @State private var showImport = false
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.message == rhs.message && lhs.isMine == rhs.isMine }
    let message: StudyMessage; let isMine: Bool
    var body: some View { HStack { if isMine { Spacer(minLength: 45) }; content.padding(12).background(isMine ? AppTheme.violet : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 19)).foregroundStyle(isMine ? Color.white : Color.primary).opacity(message.isPending ? 0.65 : 1); if !isMine { Spacer(minLength: 45) } }.accessibilityElement(children: .combine) }
    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch message.kind {
            case .text: Text(message.text)
            case .schedule: scheduleCard
            case .grades: gradesCard
            case .analytics: analyticsCard
            }
            if !isMine && (message.kind == .schedule || (message.kind == .text && !message.payload.isEmpty)) {
                Button("Посмотреть и принять") { showImport = true }.buttonStyle(.bordered)
                    .sheet(isPresented: $showImport) {
                        IncomingPlanView(messageID: message.id,
                            lessons: message.kind == .schedule ? ((try? JSONDecoder().decode([Lesson].self, from: Data(message.payload.utf8))) ?? []) : [],
                            homework: message.kind == .text ? ((try? JSONDecoder().decode([Homework].self, from: Data(message.payload.utf8))) ?? []) : [])
                    }
            }
            HStack(spacing: 4) { Text(message.sentAt.formatted(date: .omitted, time: .shortened)); if isMine { Image(systemName: message.isPending ? "clock" : "checkmark") } }.font(.system(size: 9)).opacity(0.65).frame(maxWidth: .infinity, alignment: .trailing)
        }.frame(maxWidth: 290, alignment: .leading)
    }
    private var scheduleCard: some View { let lessons = (try? JSONDecoder().decode([Lesson].self, from: Data(message.payload.utf8))) ?? []; return VStack(alignment: .leading, spacing: 7) { Label(message.text, systemImage: "calendar").font(.headline); ForEach(lessons.prefix(8)) { lesson in HStack { Text(dayName(lesson.weekday)).font(.caption.bold()).frame(width: 25); Text(lesson.title).font(.caption).lineLimit(1); Spacer(); Text(lesson.startsAt).font(.caption2.monospacedDigit()) } }; if lessons.count > 8 { Text("Ещё \(lessons.count - 8) уроков").font(.caption2).opacity(0.75) } } }
    private var gradesCard: some View { let grades = (try? JSONDecoder().decode([Grade].self, from: Data(message.payload.utf8))) ?? []; return VStack(alignment: .leading, spacing: 7) { Label(message.text, systemImage: "star.fill").font(.headline); ForEach(grades.prefix(6)) { grade in HStack { Text(grade.subject).font(.caption).lineLimit(1); Spacer(); Text("\(grade.value)").font(.headline).foregroundStyle(grade.value >= 9 ? AppTheme.gold : (isMine ? .white : AppTheme.violet)) } }; if grades.count > 6 { Text("И ещё \(grades.count - 6)").font(.caption2).opacity(0.75) } } }
    private var analyticsCard: some View { let value = try? JSONDecoder().decode(SharedAnalytics.self, from: Data(message.payload.utf8)); return HStack(spacing: 14) { ZStack { Circle().stroke(.white.opacity(isMine ? 0.22 : 0.12), lineWidth: 8); Circle().trim(from: 0, to: min(1, (value?.average ?? 0) / 10)).stroke(isMine ? Color.white : AppTheme.mint, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90)); Text(String(format: "%.1f", value?.average ?? 0)).font(.headline) }.frame(width: 74, height: 74); VStack(alignment: .leading, spacing: 5) { Text(message.text).font(.headline); Label("\(value?.excellentCount ?? 0) отличных", systemImage: "crown.fill").font(.caption); Label("\(value?.completedHomework ?? 0)/\(value?.homeworkCount ?? 0) заданий", systemImage: "checkmark.circle.fill").font(.caption) } } }
    private func dayName(_ day: Int) -> String { [2:"Пн",3:"Вт",4:"Ср",5:"Чт",6:"Пт",7:"Сб",1:"Вс"][day] ?? "" }
}
