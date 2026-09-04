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
                    showcase
                    progressCard
                    rarityPicker
                    achievementGrid
                    NavigationLink { StudentCenterView() } label: {
                        Label("Открыть центр ученика", systemImage: "square.grid.2x2.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .foregroundStyle(.white).background(accent.gradient, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(ScalePressStyle())
                }.padding()
            }
            .background { AnimatedAppBackground() }
            .navigationTitle("Профиль")
            .toolbar { Button { editingProfile = true } label: { Image(systemName: "pencil.circle") }.accessibilityLabel("Изменить профиль") }
            .sheet(isPresented: $editingProfile) { EditProfileView() }
        }
    }

    private var profileHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [accent.opacity(0.82), accent, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.12)).frame(width: 190).offset(x: 225, y: -55)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(initials).font(.system(size: 28, weight: .heavy, design: .rounded)).frame(width: 66, height: 66)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22)).overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.2)) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.studentName).font(.title2.bold())
                        Text(store.profileBio).font(.subheadline).opacity(0.8).lineLimit(2)
                    }.padding(.top, 5)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Label("\(studyStreak)", systemImage: "flame.fill").foregroundStyle(.orange)
                    Text("дней подряд").opacity(0.82)
                    Spacer()
                    Text("Уровень \(level)").fontWeight(.bold)
                }.font(.subheadline.bold()).padding(.horizontal, 13).frame(height: 42).background(.black.opacity(0.13), in: Capsule())
            }.foregroundStyle(.white).padding(21)
        }.frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).shadow(color: accent.opacity(0.28), radius: 20, y: 10)
    }

    private var showcase: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Label("Витрина", systemImage: "sparkles").font(.headline); Spacer(); Text("Лучшие 3").font(.caption.bold()).foregroundStyle(.secondary) }
                HStack(alignment: .top, spacing: 9) {
                    ForEach(pinned) { achievement in
                        VStack(spacing: 8) {
                            Image(systemName: achievement.symbol).font(.title2.bold()).foregroundStyle(rarityColor(achievement.rarity)).frame(width: 52, height: 52)
                                .background(rarityColor(achievement.rarity).opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                            Text(achievement.title).font(.caption2.bold()).multilineTextAlignment(.center).lineLimit(2).frame(height: 30, alignment: .top)
                        }.frame(maxWidth: .infinity)
                    }
                    if pinned.isEmpty { Text("Выполни первое задание — и здесь появится награда").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }
        }
    }

    private var progressCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack { Text("Коллекция достижений").font(.headline); Spacer(); Text("\(unlocked.count) / \(achievements.count)").font(.subheadline.bold()).foregroundStyle(accent) }
                ProgressView(value: Double(unlocked.count), total: Double(achievements.count)).tint(accent)
                Text("Зарабатывай награды за уроки, оценки, задания и учебную серию.").font(.caption).foregroundStyle(.secondary)
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
                            Image(systemName: unlocked ? achievement.symbol : "lock.fill").font(.title3.bold()).foregroundStyle(unlocked ? rarityColor(achievement.rarity) : .secondary)
                            Spacer()
                            if store.pinnedAchievementIDs.contains(achievement.id) { Image(systemName: "pin.fill").font(.caption).foregroundStyle(accent) }
                        }
                        Text(achievement.title).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(2)
                        Text(achievement.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        ProgressView(value: Double(min(metricValue(achievement.metric), achievement.target)), total: Double(achievement.target)).tint(unlocked ? rarityColor(achievement.rarity) : .gray)
                        Text(unlocked ? "Получено · нажми, чтобы закрепить" : "\(metricValue(achievement.metric)) из \(achievement.target)").font(.system(size: 10, weight: .semibold)).foregroundStyle(unlocked ? rarityColor(achievement.rarity) : .secondary)
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
            Text(title).font(.caption.bold()).padding(.horizontal, 14).frame(height: 38)
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
        }
    }
    private var studyStreak: Int { max(1, min(365, Set(store.homework.filter(\.isDone).compactMap { $0.createdAt.map { Calendar.current.startOfDay(for: $0) } }).count)) }
    private var level: Int { max(1, unlocked.count / 5 + 1) }
    private var initials: String { store.studentName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased().isEmpty ? "У" : store.studentName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
    private var accent: Color { [AppTheme.violet, AppTheme.blue, AppTheme.mint, AppTheme.coral][store.accentIndex % 4] }
    private func rarityColor(_ rarity: AchievementRarity) -> Color { switch rarity { case .common: .secondary; case .rare: .blue; case .epic: AppTheme.violet; case .legendary: .orange } }
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
        let groups: [(String, String, String, Achievement.Metric, [Int])] = [
            ("Домашний старт", "Выполнено заданий", "checkmark.circle.fill", .completedHomework, Array(1...30)),
            ("Опыт в журнале", "Добавлено оценок", "star.fill", .grades, Array(1...30)),
            ("Высший балл", "Оценок 9 или 10", "crown.fill", .excellentGrades, Array(1...25)),
            ("Школьный ритм", "Уроков в расписании", "calendar.badge.checkmark", .lessons, Array(1...20)),
            ("Огонь знаний", "Дней учебной серии", "flame.fill", .streak, Array(1...24))
        ]
        for group in groups {
            for (index, target) in group.4.enumerated() {
                let rarity: AchievementRarity = target <= 5 ? .common : target <= 12 ? .rare : target <= 20 ? .epic : .legendary
                result.append(Achievement(id: "\(group.3)-\(target)", title: "\(group.0) \(roman(index + 1))", detail: "\(group.1): \(target)", symbol: group.2, rarity: rarity, target: target, metric: group.3))
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
