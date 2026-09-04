import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var cloud = FirebaseProfileService()
    @AppStorage("communityPublished") private var isPublished = false
    @State private var searchCode = ""
    @State private var section = 0
    let streak: Int
    let level: Int
    let pinnedAchievementIDs: [String]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                communityHero
                Picker("Раздел", selection: $section) { Text("Профиль").tag(0); Text("Друзья").tag(1); Text("Все").tag(2); Text("Чаты").tag(3) }.pickerStyle(.segmented)
                if section == 0 { publishCard }
                else if section == 1 {
                    searchCard
                    if let profile = cloud.foundProfile { profileCard(profile, canAdd: true) }
                    friendsSection
                } else if section == 2 { allUsersSection }
                else { MessengerView(friends: cloud.friends) }
            }.padding()
        }
        .background { AnimatedAppBackground() }
        .navigationTitle("Сообщество")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if cloud.isWorking { ProgressView().controlSize(.large).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
        .task { await cloud.connect() }
        .refreshable { await cloud.connect() }
    }

    private var communityHero: some View {
        ZStack {
            AppTheme.heroGradient
            Circle().fill(.white.opacity(0.12)).frame(width: 150).offset(x: 125, y: -45)
            VStack(spacing: 11) {
                Image(systemName: "person.2.wave.2.fill").font(.system(size: 34, weight: .bold))
                Text("Учимся вместе").font(.title2.bold())
                Text("Делись кодом, находи друзей и смотри их успехи").font(.subheadline).opacity(0.78).multilineTextAlignment(.center)
            }.foregroundStyle(.white).padding(22)
        }.frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).shadow(color: AppTheme.violet.opacity(0.28), radius: 20, y: 10)
    }

    private var publishCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Мой сетевой профиль", subtitle: cloud.message.isEmpty ? "Подключение к Firebase" : cloud.message, symbol: "network")
                HStack {
                    VStack(alignment: .leading, spacing: 3) { Text("Ваш код").font(.caption).foregroundStyle(.secondary); Text(cloud.profileCode).font(.title2.monospaced().bold()).tracking(2) }
                    Spacer()
                    ShareLink(item: cloud.profileCode, subject: Text("Мой профиль в Успевай"), message: Text("Добавь меня в Успевай. Код профиля: \(cloud.profileCode)")) { Image(systemName: "square.and.arrow.up").frame(width: 46, height: 46).background(AppTheme.violet.opacity(0.11), in: RoundedRectangle(cornerRadius: 14)) }.accessibilityLabel("Поделиться кодом")
                }
                Toggle("Показывать мой профиль", isOn: $isPublished).tint(AppTheme.violet)
                Button { Task { await publish() } } label: {
                    Label(isPublished ? "Опубликовать изменения" : "Сохранить приватность", systemImage: isPublished ? "arrow.triangle.2.circlepath" : "eye.slash.fill")
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 48).foregroundStyle(.white).background(AppTheme.actionGradient, in: RoundedRectangle(cornerRadius: 15))
                }.buttonStyle(ScalePressStyle()).disabled(!cloud.accountReady || cloud.isWorking).opacity(cloud.accountReady ? 1 : 0.5)
                Text("Публикуются имя, девиз, выбранный шрифт, титул, рамка, огонёк, достижения и только общая статистика успеваемости. Сами оценки, задания и расписание остаются на устройстве.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var searchCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: "Найти друга", subtitle: "Введите его восьмизначный код", symbol: "person.badge.plus")
                HStack(spacing: 9) {
                    TextField("Например, A7K9M2QX", text: $searchCode).textInputAutocapitalization(.characters).autocorrectionDisabled().font(.body.monospaced()).padding(.horizontal, 13).frame(height: 48).background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
                    Button { Task { await cloud.search(code: searchCode) } } label: { Image(systemName: "magnifyingglass").font(.headline).foregroundStyle(.white).frame(width: 48, height: 48).background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 14)) }.buttonStyle(ScalePressStyle()).accessibilityLabel("Найти")
                }
            }
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Друзья", subtitle: cloud.friends.isEmpty ? "Добавленных друзей пока нет" : "\(cloud.friends.count) в вашем списке", symbol: "person.2.fill")
            ForEach(cloud.friends) { profile in profileCard(profile, canAdd: false) }
            if cloud.friends.isEmpty { ContentUnavailableView("Найдите первого друга", systemImage: "person.2.slash", description: Text("Попросите его отправить код профиля")) }
        }
    }

    private var allUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Все ученики", subtitle: "Открытые профили сообщества", symbol: "globe.europe.africa.fill")
            ForEach(cloud.allProfiles) { profile in profileCard(profile, canAdd: !cloud.friends.contains(profile)) }
            if cloud.allProfiles.isEmpty { ContentUnavailableView("Пока никого нет", systemImage: "person.3", description: Text("Профили появятся после первой публикации")) }
        }
    }

    private func profileCard(_ profile: PublicStudentProfile, canAdd: Bool) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 13) {
                NavigationLink { FriendProfileView(profile: profile) } label: {
                    HStack(spacing: 12) {
                        AvatarRingView(ringID: profile.ringID.isEmpty ? "ring-0" : profile.ringID, size: 54, animated: false) { Text(initials(profile.name)).font(profileFont(profile, size: 17)).foregroundStyle(.white).frame(width: 42, height: 42).background(profileAccent(profile).gradient, in: Circle()) }
                        VStack(alignment: .leading, spacing: 3) { Text(profile.name).font(profileFont(profile, size: 17)); Text(profile.title).font(profileFont(profile, size: 12).bold()).foregroundStyle(AppTheme.violet); Text(profile.bio.isEmpty ? "Ученик Успевай" : profile.bio).font(profileFont(profile, size: 11)).foregroundStyle(.secondary).lineLimit(1) }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                }.buttonStyle(.plain)
                HStack(spacing: 9) {
                    ForEach(profile.pinnedAchievementIDs.prefix(3), id: \.self) { id in
                        if let achievement = AchievementCatalog.all.first(where: { $0.id == id }) { AchievementBadgeArtwork(achievement: achievement, isUnlocked: true, size: 44) }
                    }
                    Spacer()
                    if canAdd { Button("Добавить") { Task { await cloud.add(profile: profile) } }.buttonStyle(.borderedProminent).tint(AppTheme.violet) }
                    else {
                        NavigationLink { StudyChatView(friend: profile) } label: { Image(systemName: "message.fill") }.buttonStyle(.borderedProminent).tint(AppTheme.violet).accessibilityLabel("Написать")
                        Button(role: .destructive) { cloud.removeFriend(profile) } label: { Image(systemName: "person.badge.minus") }.buttonStyle(.bordered).accessibilityLabel("Удалить друга")
                    }
                }
            }
        }
    }

    private func publish() async { let average = store.grades.isEmpty ? 0 : Double(store.grades.map(\.value).reduce(0,+)) / Double(store.grades.count); let homeworkPercent = store.homework.isEmpty ? 0 : Int(Double(store.homework.filter(\.isDone).count) / Double(store.homework.count) * 100); await cloud.publish(name: store.studentName, bio: store.profileBio, streak: streak, level: level, accentIndex: store.accentIndex, pinnedAchievementIDs: Array(pinnedAchievementIDs.prefix(3)), title: store.profileTitle, ringID: store.equippedRingID, fontID: store.equippedFontID, gradeAverage: average, gradeCount: store.grades.count, excellentCount: store.grades.filter { $0.value >= 9 }.count, homeworkPercent: homeworkPercent, isPublic: isPublished) }
    private func initials(_ name: String) -> String { let value = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased(); return value.isEmpty ? "У" : value }
    private func profileAccent(_ profile: PublicStudentProfile) -> Color { [AppTheme.violet, AppTheme.blue, AppTheme.mint, AppTheme.coral][abs(profile.accentIndex) % 4] }
    private func profileFont(_ profile: PublicStudentProfile, size: CGFloat) -> Font { guard let product = MarketCatalog.product(id: profile.fontID) else { return .system(size: size) }; return .custom(MarketCatalog.fontFamily(for: product), size: size) }
}

struct FriendProfileView: View {
    let profile: PublicStudentProfile
    var body: some View { ScrollView { VStack(spacing: 18) {
        ZStack { AppTheme.heroGradient; VStack(spacing: 10) { AvatarRingView(ringID: profile.ringID.isEmpty ? "ring-0" : profile.ringID, size: 90) { Text(initials).font(profileFont(size: 28).bold()).foregroundStyle(.white).frame(width: 70, height: 70).background(AppTheme.deepViolet, in: Circle()) }; Text(profile.name).font(profileFont(size: 22).bold()); Text(profile.title).font(profileFont(size: 15).bold()).foregroundStyle(AppTheme.gold); Text(profile.bio).font(profileFont(size: 12)).opacity(0.8) }.foregroundStyle(.white).padding() }.frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 30))
        NavigationLink { StudyChatView(friend: profile) } label: { Label("Написать сообщение", systemImage: "message.fill").font(profileFont(size: 17).bold()).frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(.white).background(AppTheme.actionGradient, in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(ScalePressStyle())
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { metric("Средний балл", profile.gradeAverage == 0 ? "—" : String(format: "%.2f", profile.gradeAverage), "chart.line.uptrend.xyaxis"); metric("Всего оценок", "\(profile.gradeCount)", "star.fill"); metric("Оценок 9–10", "\(profile.excellentCount)", "crown.fill"); metric("Задания", "\(profile.homeworkPercent)%", "checkmark.circle.fill") }
        SoftCard { VStack(alignment: .leading, spacing: 12) { Label("Лучшие достижения", systemImage: "sparkles").font(profileFont(size: 17).bold()); HStack { ForEach(profile.pinnedAchievementIDs.prefix(3), id: \.self) { id in if let achievement = AchievementCatalog.all.first(where: { $0.id == id }) { AchievementBadgeArtwork(achievement: achievement, isUnlocked: true, size: 62) } } } } }
    }.padding() }.font(profileFont).background { AnimatedAppBackground() }.navigationTitle("Профиль").navigationBarTitleDisplayMode(.inline) }
    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View { SoftCard { VStack(alignment: .leading, spacing: 7) { Image(systemName: symbol).foregroundStyle(AppTheme.violet); Text(value).font(profileFont(size: 22).bold()); Text(title).font(profileFont(size: 12)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
    private var initials: String { let value = profile.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased(); return value.isEmpty ? "У" : value }
    private var profileFont: Font { guard let product = MarketCatalog.product(id: profile.fontID) else { return .body }; return .custom(MarketCatalog.fontFamily(for: product), size: 17, relativeTo: .body) }
    private func profileFont(size: CGFloat) -> Font { guard let product = MarketCatalog.product(id: profile.fontID) else { return .system(size: size) }; return .custom(MarketCatalog.fontFamily(for: product), size: size) }
}
