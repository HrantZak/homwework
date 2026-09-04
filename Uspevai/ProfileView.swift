import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedRarity: AchievementRarity?
    @State private var editingProfile = false

    private var achievements: [Achievement] { AchievementCatalog.all }
    private var unlocked: [Achievement] { achievements.filter(isUnlocked) }
    private var shown: [Achievement] { selectedRarity.map { rarity in achievements.filter { $0.rarity == rarity } } ?? achievements }
    private var pinned: [Achievement] {
        let chosen = store.pinnedAchievementIDs.compactMap { id in achievements.first { $0.id == id && isUnlocked($0) } }
        return Array((chosen + unlocked.filter { item in !chosen.contains(item) }).prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    profileHero
                    NavigationLink { CommunityView(streak: studyStreak, level: level, pinnedAchievementIDs: pinned.map(\.id)) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.2.wave.2.fill").font(.title2.bold()).foregroundStyle(.white).frame(width: 52, height: 52).background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 17))
                            VStack(alignment: .leading, spacing: 4) { Text("Сообщество Успевай").font(store.activeFont(size: 17, relativeTo: .headline).bold()); Text("Найди друзей и посмотри их достижения").font(store.activeFont(size: 12, relativeTo: .caption)).opacity(0.78).multilineTextAlignment(.leading) }
                            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).opacity(0.7)
                        }.padding(17).foregroundStyle(.white).background(LinearGradient(colors: [AppTheme.mint, AppTheme.blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(ScalePressStyle())
                    showcase
                    progressCard
                    rarityPicker
                    achievementGrid
                    NavigationLink { StudentCenterView() } label: {
                        Label("Открыть центр ученика", systemImage: "square.grid.2x2.fill")
                            .font(store.activeFont(size: 17, relativeTo: .headline).bold()).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .foregroundStyle(.white).background(accent.gradient, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(ScalePressStyle())
                }.padding()
            }
            .font(store.activeAppFont)
            .background { AnimatedAppBackground() }
            .navigationTitle("Профиль")
            .toolbar { Button { editingProfile = true } label: { Image(systemName: "pencil.circle") }.accessibilityLabel("Изменить профиль") }
            .sheet(isPresented: $editingProfile) { EditProfileView() }
        }
    }

    private var profileHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [AppTheme.deepViolet, accent, AppTheme.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.12)).frame(width: 190).offset(x: 225, y: -55)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    AvatarRingView(ringID: store.equippedRingID.isEmpty ? "ring-0" : store.equippedRingID, size: 72) {
                        Text(initials).font(store.activeFont(size: 25, relativeTo: .title2).bold()).frame(width: 56, height: 56).background(.white.opacity(0.18), in: Circle())
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.studentName).font(store.activeFont(size: 22, relativeTo: .title2).bold())
                        Text(store.profileTitle).font(store.activeFont(size: 12, relativeTo: .caption).bold()).foregroundStyle(AppTheme.gold)
                        Text(store.profileBio).font(store.activeFont(size: 15, relativeTo: .subheadline)).opacity(0.8).lineLimit(1)
                    }.padding(.top, 5)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Label("\(studyStreak)", systemImage: "flame.fill").foregroundStyle(.orange)
                    Text("дней подряд").opacity(0.82)
                    Spacer()
                    Text("Уровень \(level)").fontWeight(.bold)
                }.font(store.activeFont(size: 15, relativeTo: .subheadline).bold()).padding(.horizontal, 13).frame(height: 42).background(.black.opacity(0.13), in: Capsule())
            }.foregroundStyle(.white).padding(21)
        }.frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).shadow(color: accent.opacity(0.28), radius: 20, y: 10)
    }

    private var showcase: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Label("Витрина", systemImage: "sparkles").font(store.activeFont(size: 17, relativeTo: .headline).bold()); Spacer(); Text("Лучшие 3").font(store.activeFont(size: 12, relativeTo: .caption).bold()).foregroundStyle(.secondary) }
                HStack(alignment: .top, spacing: 9) {
                    ForEach(pinned) { achievement in
                        VStack(spacing: 8) {
                            AchievementBadgeArtwork(achievement: achievement, isUnlocked: true, size: 58)
                            Text(achievement.title).font(store.activeFont(size: 11, relativeTo: .caption2).bold()).multilineTextAlignment(.center).lineLimit(2).frame(height: 30, alignment: .top)
                        }.frame(maxWidth: .infinity)
                    }
                    if pinned.isEmpty { Text("Выполни первое задание — и здесь появится награда").font(store.activeFont(size: 15, relativeTo: .subheadline)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }
        }
    }

    private var progressCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack { Text("Коллекция достижений").font(store.activeFont(size: 17, relativeTo: .headline).bold()); Spacer(); Text("\(unlocked.count) / \(achievements.count)").font(store.activeFont(size: 15, relativeTo: .subheadline).bold()).foregroundStyle(accent) }
                ProgressView(value: Double(unlocked.count), total: Double(achievements.count)).tint(accent)
                Text("Зарабатывай награды за задания, оценки, посещения, экзамены, заметки и коллекцию.").font(store.activeFont(size: 12, relativeTo: .caption)).foregroundStyle(.secondary)
            }
        }
    }

    private var rarityPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton("Все", rarity: nil)
                ForEach(AchievementRarity.allCases, id: \.self) { rarity in filterButton(rarity.title, rarity: rarity) }
            }
        }
    }

    private var achievementGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(shown) { achievement in
                let unlocked = isUnlocked(achievement)
                Button { togglePin(achievement) } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            AchievementBadgeArtwork(achievement: achievement, isUnlocked: unlocked, size: 52)
                            Spacer()
                            if store.pinnedAchievementIDs.contains(achievement.id) { Image(systemName: "pin.fill").font(.caption).foregroundStyle(accent) }
                        }
                        Text(achievement.title).font(store.activeFont(size: 15, relativeTo: .subheadline).bold()).foregroundStyle(.primary).lineLimit(2)
                        Text(achievement.detail).font(store.activeFont(size: 11, relativeTo: .caption2)).foregroundStyle(.secondary).lineLimit(2)
                        ProgressView(value: Double(min(metricValue(achievement.metric), achievement.target)), total: Double(achievement.target)).tint(unlocked ? rarityColor(achievement.rarity) : .gray)
                        Text(unlocked ? "Получено · нажми, чтобы закрепить" : "\(metricValue(achievement.metric)) из \(achievement.target)").font(store.activeFont(size: 10, relativeTo: .caption2).bold()).foregroundStyle(unlocked ? rarityColor(achievement.rarity) : .secondary)
                    }.padding(14).frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 21))
                        .overlay { RoundedRectangle(cornerRadius: 21).stroke((unlocked ? rarityColor(achievement.rarity) : Color.primary).opacity(0.13)) }
                        .opacity(unlocked ? 1 : 0.72)
                }.buttonStyle(ScalePressStyle()).disabled(!unlocked)
            }
        }
    }

    private func filterButton(_ title: String, rarity: AchievementRarity?) -> some View {
        Button { withAnimation(.snappy) { selectedRarity = rarity } } label: {
            Text(title).font(store.activeFont(size: 12, relativeTo: .caption).bold()).padding(.horizontal, 14).frame(height: 38)
                .foregroundStyle(selectedRarity == rarity ? .white : .primary).background(selectedRarity == rarity ? accent : Color.primary.opacity(0.07), in: Capsule())
        }.buttonStyle(ScalePressStyle())
    }

    private func togglePin(_ achievement: Achievement) {
        if let index = store.pinnedAchievementIDs.firstIndex(of: achievement.id) { store.pinnedAchievementIDs.remove(at: index) }
        else { store.pinnedAchievementIDs.append(achievement.id); if store.pinnedAchievementIDs.count > 3 { store.pinnedAchievementIDs.removeFirst() } }
    }
    private func isUnlocked(_ item: Achievement) -> Bool { metricValue(item.metric) >= item.target }
    private func metricValue(_ metric: Achievement.Metric) -> Int {
        switch metric {
        case .completedHomework: store.homework.filter(\.isDone).count
        case .grades: store.grades.count
        case .excellentGrades: store.grades.filter { $0.value >= 9 }.count
        case .lessons: store.lessons.count
        case .streak: studyStreak
        case .profile: store.studentName == "Ученик" ? 0 : 1
        case .attendance: store.attendance.filter(\.wasPresent).count
        case .exams: store.exams.count
        case .notes: store.notes.count
        case .collection: store.purchasedMarketIDs.count
        }
    }
    private var studyStreak: Int { max(1, min(365, Set(store.homework.filter(\.isDone).compactMap { $0.createdAt.map { Calendar.current.startOfDay(for: $0) } }).count)) }
    private var level: Int { max(1, unlocked.count / 5 + 1) }
    private var initials: String { store.studentName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased().isEmpty ? "У" : store.studentName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
    private var accent: Color { [AppTheme.violet, AppTheme.blue, AppTheme.mint, AppTheme.coral][store.accentIndex % 4] }
    private func rarityColor(_ rarity: AchievementRarity) -> Color { switch rarity { case .common: .secondary; case .rare: .blue; case .epic: AppTheme.violet; case .legendary: .orange; case .mythical: .pink } }
}

struct AchievementBadgeArtwork: View {
    let achievement: Achievement
    let isUnlocked: Bool
    var size: CGFloat = 56

    private var seed: Int {
        achievement.id.unicodeScalars.enumerated().reduce(17) { partial, item in
            (partial &* 31 &+ Int(item.element.value) &* (item.offset + 1)) & 0x7fffffff
        }
    }
    private var baseHue: Double { Double(seed % 360) / 360 }
    private var secondaryHue: Double { (baseHue + 0.10 + Double((seed / 7) % 25) / 100).truncatingRemainder(dividingBy: 1) }
    private var points: Int { 5 + seed % 5 }
    private var rotation: Double { Double(seed % 45) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(backgroundGradient)
            pattern.opacity(isUnlocked ? 0.42 : 0.12)
            Circle().fill(.white.opacity(isUnlocked ? 0.18 : 0.07)).frame(width: size * 0.68)
                .overlay { Circle().stroke(.white.opacity(0.24), lineWidth: max(1, size * 0.018)) }
            Image(systemName: isUnlocked ? achievement.symbol : "lock.fill")
                .font(.system(size: size * 0.35, weight: .black, design: .rounded))
                .foregroundStyle(isUnlocked ? Color.white : Color.secondary)
                .shadow(color: .black.opacity(isUnlocked ? 0.24 : 0), radius: 2, y: 1)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(shortRank).font(.system(size: max(7, size * 0.13), weight: .black, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white).padding(.horizontal, size * 0.08).frame(minHeight: size * 0.21)
                        .background(.black.opacity(0.28), in: Capsule())
                }
            }.padding(size * 0.09)
        }
        .frame(width: size, height: size)
        .saturation(isUnlocked ? 1 : 0)
        .overlay { RoundedRectangle(cornerRadius: size * 0.31, style: .continuous).strokeBorder(borderGradient, lineWidth: rarityLineWidth) }
        .shadow(color: isUnlocked ? primaryColor.opacity(0.28) : .clear, radius: size * 0.13, y: size * 0.06)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(achievement.title), \(achievement.rarity.title)")
    }

    @ViewBuilder private var pattern: some View {
        switch seed % 6 {
        case 0:
            ForEach(0..<points, id: \.self) { index in
                Capsule().fill(.white).frame(width: size * 0.055, height: size * 0.82)
                    .rotationEffect(.degrees(Double(index) * 180 / Double(points) + rotation))
            }
        case 1:
            ZStack {
                ForEach(1..<4, id: \.self) { index in Circle().stroke(.white, lineWidth: size * 0.025).frame(width: size * CGFloat(index) * 0.25) }
            }
        case 2:
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.07).stroke(.white, lineWidth: size * 0.025)
                    .frame(width: size * (0.25 + CGFloat(index) * 0.18), height: size * (0.25 + CGFloat(index) * 0.18))
                    .rotationEffect(.degrees(rotation + Double(index * 12)))
            }
        case 3:
            HStack(spacing: size * 0.08) { ForEach(0..<5, id: \.self) { _ in Capsule().fill(.white).frame(width: size * 0.065, height: size * 0.78) } }
                .rotationEffect(.degrees(rotation - 22))
        case 4:
            ZStack { ForEach(0..<points, id: \.self) { index in Circle().fill(.white).frame(width: size * 0.11).offset(y: -size * 0.39).rotationEffect(.degrees(Double(index) * 360 / Double(points) + rotation)) } }
        default:
            Image(systemName: "sparkles").font(.system(size: size * 0.82, weight: .thin)).foregroundStyle(.white).rotationEffect(.degrees(rotation))
        }
    }

    private var primaryColor: Color { isUnlocked ? Color(hue: baseHue, saturation: raritySaturation, brightness: rarityBrightness) : Color.gray.opacity(0.55) }
    private var secondaryColor: Color { isUnlocked ? Color(hue: secondaryHue, saturation: min(1, raritySaturation + 0.08), brightness: min(1, rarityBrightness + 0.08)) : Color.gray.opacity(0.3) }
    private var backgroundGradient: LinearGradient { LinearGradient(colors: [primaryColor, secondaryColor], startPoint: gradientStart, endPoint: gradientEnd) }
    private var borderGradient: LinearGradient { LinearGradient(colors: [.white.opacity(isUnlocked ? 0.82 : 0.25), rarityAccent, .white.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing) }
    private var gradientStart: UnitPoint { seed % 2 == 0 ? .topLeading : .topTrailing }
    private var gradientEnd: UnitPoint { seed % 2 == 0 ? .bottomTrailing : .bottomLeading }
    private var raritySaturation: Double { switch achievement.rarity { case .common: 0.48; case .rare: 0.66; case .epic: 0.78; case .legendary: 0.88; case .mythical: 0.98 } }
    private var rarityBrightness: Double { switch achievement.rarity { case .common: 0.72; case .rare: 0.80; case .epic: 0.76; case .legendary: 0.95; case .mythical: 1.0 } }
    private var rarityLineWidth: CGFloat { switch achievement.rarity { case .common: 1; case .rare: 1.5; case .epic: 2; case .legendary: 2.5; case .mythical: 3.5 } }
    private var rarityAccent: Color { switch achievement.rarity { case .common: .white.opacity(0.45); case .rare: .cyan; case .epic: .purple; case .legendary: .yellow; case .mythical: .pink } }
    private var shortRank: String { achievement.id.split(separator: "-").last.map(String.init) ?? "1" }
}

private struct EditProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { Form {
            Section("О тебе") { TextField("Имя", text: $store.studentName); TextField("Короткий девиз", text: $store.profileBio, axis: .vertical).lineLimit(2...4) }
            Section("Цвет профиля") { Picker("Акцент", selection: $store.accentIndex) { Text("Фиолетовый").tag(0); Text("Синий").tag(1); Text("Мятный").tag(2); Text("Коралловый").tag(3) }.pickerStyle(.inline) }
            Section { NavigationLink { SettingsView() } label: { Label("Все настройки", systemImage: "gearshape.fill") } }
        }.navigationTitle("Настройка профиля").navigationBarTitleDisplayMode(.inline).toolbar { Button("Готово") { dismiss() } } }
    }
}

enum AchievementCatalog {
    static let all: [Achievement] = {
        var result: [Achievement] = [
            Achievement(id: "profile", title: "Это я", detail: "Заполни имя в профиле", symbol: "person.crop.circle.badge.checkmark", rarity: .common, target: 1, metric: .profile)
        ]
        let longTargets = [1, 2, 3, 4, 5, 8, 12, 16, 20, 24, 30, 90]
        let groups: [(String, String, String, Achievement.Metric, [Int])] = [
            ("Домашний старт", "Выполнено заданий", "checkmark.circle.fill", .completedHomework, longTargets),
            ("Опыт в журнале", "Добавлено оценок", "star.fill", .grades, longTargets),
            ("Высший балл", "Оценок 9 или 10", "crown.fill", .excellentGrades, longTargets),
            ("Школьный ритм", "Уроков в расписании", "calendar.badge.checkmark", .lessons, longTargets),
            ("Огонь знаний", "Дней учебной серии", "flame.fill", .streak, longTargets),
            ("Всегда вовремя", "Посещено занятий", "clock.badge.checkmark.fill", .attendance, longTargets),
            ("Готов к проверке", "Добавлено экзаменов", "graduationcap.fill", .exams, longTargets),
            ("Хранитель мыслей", "Создано заметок", "note.text", .notes, longTargets),
            ("Коллекционер", "Куплено предметов", "sparkles.rectangle.stack.fill", .collection, longTargets)
        ]
        for group in groups {
            for (index, target) in group.4.enumerated() {
                let rarity: AchievementRarity = target == 90 ? .mythical : target <= 5 ? .common : target <= 12 ? .rare : target <= 20 ? .epic : .legendary
                let detail = rarity == .mythical ? "\(group.1): \(target) · в 3 раза сложнее легендарного" : "\(group.1): \(target)"
                result.append(Achievement(id: "\(group.3)-\(target)", title: "\(group.0) \(roman(index + 1))", detail: detail, symbol: group.2, rarity: rarity, target: target, metric: group.3))
            }
        }
        return result
    }()

    private static func roman(_ value: Int) -> String {
        let values = [(10,"X"),(9,"IX"),(5,"V"),(4,"IV"),(1,"I")]
        var number = value; var output = ""
        for pair in values { while number >= pair.0 { output += pair.1; number -= pair.0 } }
        return output
    }
}
