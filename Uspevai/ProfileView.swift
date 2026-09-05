import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedRarity: AchievementRarity?
    @State private var editingProfile = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onlyUnlocked = false

    private var achievements: [Achievement] { AchievementCatalog.all }
    private var unlocked: [Achievement] { achievements.filter(isUnlocked) }
    private var shown: [Achievement] { achievements.filter { (selectedRarity == nil || $0.rarity == selectedRarity) && (!onlyUnlocked || isUnlocked($0)) } }
    private var pinned: [Achievement] {
        let chosen = store.pinnedAchievementIDs.compactMap { id in achievements.first { $0.id == id && isUnlocked($0) } }
        return Array((chosen + unlocked.filter { item in !chosen.contains(item) }).prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    profileHero.revealOnAppear()
                    statistics
                    NavigationLink { CommunityView(streak: studyStreak, level: level, pinnedAchievementIDs: pinned.map(\.id)) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.2.wave.2.fill").font(.title2.bold()).foregroundStyle(.white).frame(width: 52, height: 52).background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 17))
                            VStack(alignment: .leading, spacing: 4) { Text("Сообщество Успевай").font(store.activeFont(size: 17, relativeTo: .headline).bold()); Text("Найди друзей и посмотри их достижения").font(store.activeFont(size: 12, relativeTo: .caption)).opacity(0.78).multilineTextAlignment(.leading) }
                            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).opacity(0.7)
                        }.padding(17).foregroundStyle(.white).background(LinearGradient(colors: [AppTheme.mint, AppTheme.blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(ScalePressStyle())
                    showcase
                    progressCard
                    SectionHeader(title: "Твои достижения", subtitle: "Маленькие шаги. Большие результаты.")
                    Toggle("Только полученные", isOn: $onlyUnlocked).tint(accent)
                    rarityPicker
                    if shown.isEmpty { ContentUnavailableView("Награды ещё впереди", systemImage: "trophy", description: Text("Выбери другую редкость или покажи все достижения.")) }
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
            .sensoryFeedback(.selection, trigger: store.pinnedAchievementIDs)
            .sheet(isPresented: $editingProfile) { EditProfileView() }
        }
    }

    private var profileHero: some View {
        VStack(spacing: 20) {
            HStack {
                Label("ТВОЯ ОРБИТА", systemImage: "sparkle").font(.caption2.bold()).tracking(2)
                Spacer()
                Label("Уровень \(level)", systemImage: "bolt.fill").font(.caption.bold())
                    .padding(10).background(.white.opacity(0.12), in: Capsule())
            }.foregroundStyle(.white.opacity(0.8))
            AvatarRingView(ringID: store.equippedRingID.isEmpty ? "ring-0" : store.equippedRingID, size: 104) {
                Text(initials).font(store.activeFont(size: 34, relativeTo: .largeTitle).bold())
                    .frame(width: 84, height: 84).background(.white.opacity(0.13), in: Circle())
            }.padding(4)
            VStack(spacing: 8) {
                Text(store.studentName).font(store.activeFont(size: 28, relativeTo: .title).bold()).multilineTextAlignment(.center)
                Label(store.profileTitle, systemImage: "crown.fill").font(.caption.bold()).foregroundStyle(AppTheme.gold)
                Text(store.profileBio).font(.subheadline).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center).lineLimit(3)
            }
            HStack(spacing: 12) {
                Label("\(studyStreak) дн. подряд", systemImage: "flame.fill")
                Spacer()
                Text("\(unlocked.count) наград")
            }.font(.subheadline.bold()).padding(15).background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
        }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity)
            .background { OrbitBackdrop(color: accent) }
            .clipShape(RoundedRectangle(cornerRadius: 32))
    }

    private var statistics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            OrbitMetric(title: "Средний балл", value: store.grades.isEmpty ? "—" : String(format: "%.1f", store.study.average), detail: "из 10 баллов", progress: store.study.average / 10, symbol: "star.fill", color: AppTheme.gold)
            OrbitMetric(title: "Задания", value: "\(store.study.completed)", detail: "из \(store.homework.count) выполнено", progress: store.homework.isEmpty ? 0 : Double(store.study.completed) / Double(store.homework.count), symbol: "checkmark", color: AppTheme.mint)
            OrbitMetric(title: "Посещение", value: store.attendance.isEmpty ? "—" : "\(Int(attendanceProgress * 100))%", detail: store.attendance.isEmpty ? "Добавь посещения" : "\(store.study.present) занятий", progress: attendanceProgress, symbol: "person.fill.checkmark", color: AppTheme.cyan)
            OrbitMetric(title: "Достижения", value: "\(unlocked.count)", detail: "из \(achievements.count) открыто", progress: Double(unlocked.count) / Double(max(1, achievements.count)), symbol: "trophy.fill", color: accent)
        }
    }
    private var attendanceProgress: Double { store.attendance.isEmpty ? 0 : Double(store.study.present) / Double(store.attendance.count) }

    private var showcase: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Label("Витрина", systemImage: "sparkles").font(store.activeFont(size: 17, relativeTo: .headline).bold()); Spacer(); Text("Лучшие 3").font(store.activeFont(size: 12, relativeTo: .caption).bold()).foregroundStyle(.secondary) }
                if pinned.isEmpty { Label("Здесь будут твои первые награды. Выполни задание или заполни профиль.", systemImage: "sparkles").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 10) }
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
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: Double(unlocked.count % 5) / 5, color: accent, size: 70, lineWidth: 6)
                    Text("\(level)").font(.system(.title, design: .rounded, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Следующий уровень").font(.headline)
                    Text("Ещё \(5 - unlocked.count % 5) наград до уровня \(level + 1)").font(.subheadline).foregroundStyle(.secondary)
                    Text("Каждые пять достижений — новый уровень.").font(.caption).foregroundStyle(.secondary)
                }
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
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
                        Text(unlocked ? (store.pinnedAchievementIDs.contains(achievement.id) ? "Закреплено · нажми, чтобы снять" : "Получено · нажми, чтобы закрепить") : "\(metricValue(achievement.metric)) из \(achievement.target)").font(store.activeFont(size: 10, relativeTo: .caption2).bold()).foregroundStyle(unlocked ? rarityColor(achievement.rarity) : .secondary)
                    }.padding(14).frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 21))
                        .overlay { RoundedRectangle(cornerRadius: 21).stroke((unlocked ? rarityColor(achievement.rarity) : Color.primary).opacity(0.13)) }
                        .opacity(unlocked ? 1 : 0.72)
                }.buttonStyle(ScalePressStyle()).disabled(!unlocked).revealOnAppear()
            }
        }
    }

    private func filterButton(_ title: String, rarity: AchievementRarity?) -> some View {
        Button { withAnimation(reduceMotion ? nil : .snappy) { selectedRarity = rarity } } label: {
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
        case .completedHomework: store.study.completed
        case .grades: store.grades.count
        case .excellentGrades: store.study.excellent
        case .lessons: store.lessons.count
        case .streak: studyStreak
        case .profile: store.studentName == "Ученик" ? 0 : 1
        case .attendance: store.study.present
        case .exams: store.exams.count
        case .notes: store.notes.count
        case .collection: store.purchasedMarketIDs.count
        }
    }
    private var studyStreak: Int { store.study.streak() }
    private var level: Int { max(1, unlocked.count / 5 + 1) }
    private var initials: String { store.studentName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased().isEmpty ? "У" : store.studentName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
    private var accent: Color { [AppTheme.violet, AppTheme.blue, AppTheme.mint, AppTheme.coral][((store.accentIndex % 4) + 4) % 4] }
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
    @State private var name = ""
    @State private var bio = ""
    @State private var accent = 0
    private let colors = [AppTheme.violet, AppTheme.blue, AppTheme.mint, AppTheme.coral]
    private let names = ["Фиолетовый", "Синий", "Мятный", "Коралловый"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Твой профиль") {
                    TextField("Имя", text: $name).textContentType(.name)
                    TextField("Короткий девиз", text: $bio, axis: .vertical).lineLimit(2...4)
                }
                Section("Твой цвет") {
                    HStack(spacing: 18) {
                        ForEach(0..<4) { index in
                            Button { accent = index } label: {
                                Circle().fill(colors[index].gradient).frame(width: 44, height: 44)
                                    .overlay { if accent == index { Image(systemName: "checkmark").font(.headline).foregroundStyle(.white) } }
                            }.buttonStyle(ScalePressStyle()).accessibilityLabel(names[index]).accessibilityAddTraits(accent == index ? .isSelected : [])
                        }
                    }.padding(.vertical, 8)
                }
                Section { NavigationLink { SettingsView() } label: { Label("Все настройки", systemImage: "gearshape.fill") } }
            }.scrollContentBackground(.hidden).background { AnimatedAppBackground() }
                .navigationTitle("Это ты").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            store.studentName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
                            store.profileBio = String(bio.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
                            store.accentIndex = accent
                            dismiss()
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear { name = store.studentName; bio = store.profileBio; accent = ((store.accentIndex % 4) + 4) % 4 }
                .sensoryFeedback(.selection, trigger: accent)
        }
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
