import SwiftUI

struct StudentCenterView: View {
    @EnvironmentObject var store: AppStore
    @State private var targetGrade = 8
    @State private var futureGrades = 3
    @State private var focusMinutes = 25
    @State private var focusLeft = 0
    @State private var focusing = false
    @State private var showAllTools = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var average: Double { weightedAverage(store.grades) }
    private var homeworkProgress: Double { store.homework.isEmpty ? 0 : Double(store.homework.filter(\.isDone).count) / Double(store.homework.count) }
    private var attendanceRate: Int { store.attendance.isEmpty ? 100 : Int(Double(store.attendance.filter(\.wasPresent).count) / Double(store.attendance.count) * 100) }
    private var nextExam: Exam? { store.exams.filter { $0.date >= Date() }.sorted { $0.date < $1.date }.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metric("Средний балл", average == 0 ? "—" : String(format: "%.2f", average), "chart.line.uptrend.xyaxis", AppTheme.mint)
                        metric("Посещение", "\(attendanceRate)%", "person.fill.checkmark", .blue)
                        metric("Задания", "\(Int(homeworkProgress * 100))%", "checkmark.circle.fill", AppTheme.violet)
                        metric("До четверти", "\(daysToTerm) дн.", "calendar.badge.clock", AppTheme.coral)
                    }
                    quickLinks
                    focusCard
                    targetCalculator
                    gradeDistribution
                    smartFeed
                    Button { showAllTools = true } label: { Label("Все 50+ возможностей", systemImage: "sparkles.rectangle.stack.fill").font(.headline).frame(maxWidth: .infinity).padding().foregroundStyle(.white).background(LinearGradient(colors: [AppTheme.violet, AppTheme.blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(ScalePressStyle())
                }.padding()
            }.background { AnimatedAppBackground() }.navigationTitle("Центр ученика")
                .sheet(isPresented: $showAllTools) { AllToolsView() }
                .onReceive(timer) { _ in if focusing && focusLeft > 0 { focusLeft -= 1 } else if focusLeft == 0 { focusing = false } }
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(red: 0.18, green: 0.07, blue: 0.62), AppTheme.violet, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.12)).frame(width: 170).offset(x: 230, y: -55)
            VStack(alignment: .leading, spacing: 7) { Text("ТВОЙ УЧЕБНЫЙ ЦЕНТР").font(.caption2.bold()).tracking(1.6).opacity(0.75); Text(greeting).font(.system(size: 27, weight: .heavy, design: .rounded)); Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.subheadline).opacity(0.8) }.foregroundStyle(.white).padding(22)
        }.frame(height: 155).clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous)).shadow(color: AppTheme.violet.opacity(0.27), radius: 22, y: 12)
    }

    private var quickLinks: some View {
        SoftCard { VStack(alignment: .leading, spacing: 13) { Text("Быстрый доступ").font(.headline); HStack { NavigationLink { TrackerView() } label: { quick("Аналитика", "chart.bar.fill", AppTheme.mint) }; NavigationLink { SettingsView() } label: { quick("Настройки", "slider.horizontal.3", .blue) }; NavigationLink { ImportScheduleView() } label: { quick("Фото", "camera.fill", AppTheme.coral) } }.buttonStyle(ScalePressStyle()) } }
    }

    private var focusCard: some View {
        SoftCard { VStack(alignment: .leading, spacing: 14) { HStack { Label("Таймер фокуса", systemImage: "timer").font(.headline); Spacer(); Text(clockText).font(.title2.monospacedDigit().bold()).foregroundStyle(AppTheme.violet) }; HStack(spacing: 7) { ForEach([15,25,40,50,60,90], id: \.self) { value in Button("\(value)") { focusMinutes = value; focusLeft = value*60; focusing = false }.font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 9).background(focusMinutes == value ? AppTheme.violet : Color.primary.opacity(0.06), in: Capsule()).foregroundStyle(focusMinutes == value ? Color.white : Color.primary).buttonStyle(ScalePressStyle()) } }; ProgressView(value: Double(focusLeft == 0 ? 0 : focusMinutes*60-focusLeft), total: Double(max(1,focusMinutes*60))).tint(AppTheme.violet); Button(focusing ? "Пауза" : focusLeft == 0 ? "Начать" : "Продолжить") { if focusLeft == 0 { focusLeft = focusMinutes*60 }; focusing.toggle() }.buttonStyle(.borderedProminent).tint(AppTheme.violet) } }
    }

    private var targetCalculator: some View {
        SoftCard { VStack(alignment: .leading, spacing: 13) { Label("Калькулятор цели", systemImage: "target").font(.headline); HStack { Stepper("Цель: \(targetGrade)", value: $targetGrade, in: 1...10); Stepper("Оценок: \(futureGrades)", value: $futureGrades, in: 1...20) }; Divider(); HStack { VStack(alignment: .leading) { Text("Нужный средний").font(.caption).foregroundStyle(.secondary); Text(requiredAverageText).font(.title2.bold()).foregroundStyle(requiredAverage > 10 ? AppTheme.coral : AppTheme.mint) }; Spacer(); Image(systemName: requiredAverage > 10 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill").font(.largeTitle).foregroundStyle(requiredAverage > 10 ? AppTheme.coral : AppTheme.mint) } } }
    }

    private var gradeDistribution: some View {
        SoftCard { VStack(alignment: .leading, spacing: 12) { Label("Распределение баллов", systemImage: "chart.bar.xaxis").font(.headline); HStack(alignment: .bottom, spacing: 6) { ForEach(1...10, id: \.self) { value in let count = store.grades.filter { $0.value == value }.count; VStack(spacing: 4) { Text(count == 0 ? "" : "\(count)").font(.system(size: 8, weight: .bold)); RoundedRectangle(cornerRadius: 4).fill(color(value).gradient).frame(height: CGFloat(max(5, count*13))); Text("\(value)").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) } }.frame(height: 100, alignment: .bottom) } }
    }

    private var smartFeed: some View {
        VStack(alignment: .leading, spacing: 12) { Text("Важно сейчас").font(.title3.bold()); if let exam = nextExam { info("Ближайшее: \(exam.title)", "\(exam.subject) • \(exam.date.formatted(date: .abbreviated, time: .shortened))", "calendar.badge.exclamationmark", AppTheme.coral) }; let undone = store.homework.filter { !$0.isDone }.count; info(undone == 0 ? "Все задания выполнены" : "Осталось заданий: \(undone)", undone == 0 ? "Отличная работа" : "Начни с ближайшего срока", undone == 0 ? "checkmark.seal.fill" : "list.bullet.clipboard", undone == 0 ? AppTheme.mint : AppTheme.violet); if attendanceRate < 80 { info("Посещаемость ниже 80%", "Старайся не пропускать уроки", "person.crop.circle.badge.exclamationmark", AppTheme.coral) } }
    }

    private func metric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View { SoftCard { VStack(alignment: .leading, spacing: 9) { Image(systemName: icon).foregroundStyle(color).font(.title3); Text(value).font(.title2.bold()).contentTransition(.numericText()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
    private func quick(_ title: String, _ icon: String, _ color: Color) -> some View { VStack(spacing: 8) { Image(systemName: icon).font(.title2).foregroundStyle(.white).frame(width: 48, height: 48).background(color.gradient, in: RoundedRectangle(cornerRadius: 15)); Text(title).font(.caption.bold()).foregroundStyle(.primary) }.frame(maxWidth: .infinity) }
    private func info(_ title: String, _ subtitle: String, _ icon: String, _ color: Color) -> some View { SoftCard { HStack(spacing: 13) { Image(systemName: icon).font(.title2).foregroundStyle(color).frame(width: 38); VStack(alignment: .leading) { Text(title).font(.subheadline.bold()); Text(subtitle).font(.caption).foregroundStyle(.secondary) }; Spacer() } } }
    private func weightedAverage(_ values: [Grade]) -> Double { let weights = values.map { $0.weight ?? 1 }.reduce(0,+); return weights == 0 ? 0 : Double(values.map { $0.value * ($0.weight ?? 1) }.reduce(0,+))/Double(weights) }
    private var requiredAverage: Double { let count = store.grades.count; return futureGrades == 0 ? 0 : (Double(targetGrade * (count + futureGrades)) - average * Double(count)) / Double(futureGrades) }
    private var requiredAverageText: String { requiredAverage > 10 ? "Выше 10 — измени цель" : String(format: "%.2f из 10", max(1,requiredAverage)) }
    private var daysToTerm: Int { max(0, Calendar.current.dateComponents([.day], from: Date(), to: store.termEnd).day ?? 0) }
    private var clockText: String { let seconds = focusLeft == 0 ? focusMinutes*60 : focusLeft; return String(format: "%02d:%02d", seconds/60, seconds%60) }
    private var greeting: String { let hour = Calendar.current.component(.hour, from: Date()); return hour < 12 ? "Доброе утро" : hour < 18 ? "Добрый день" : "Добрый вечер" }
    private func color(_ grade: Int) -> Color { grade >= 8 ? AppTheme.mint : grade >= 6 ? .blue : grade >= 4 ? .orange : AppTheme.coral }
}

struct AllToolsView: View {
    @Environment(\.dismiss) var dismiss
    private let groups: [(String, String, [String])] = [
        ("Расписание", "calendar", ["Выбор конкретной даты","Переход по дням","Импорт расписания с фото","Распознавание армянского текста","Перевод предметов на русский","Редактирование урока","Время начала и окончания","Преподаватели","Дни без уроков","Уведомления после звонка"]),
        ("Оценки", "star.fill", ["10-балльная система","Оценка возле урока","Оценка за конкретную дату","Замена оценки","Тип работы","Вес контрольной","Комментарий учителя","Взвешенный средний","Прогноз четвертной","Сценарий следующей оценки"]),
        ("Журнал", "tablecells", ["Календарь оценок","Зелёные дни с оценками","Заблокированные выходные","Расписание выбранного дня","Табличный вид","Карточный вид","Поиск предмета","Фильтр предмета","Подробности оценки","Удаление ошибки"]),
        ("Организация", "checkmark.circle", ["Домашние задания","Срок выполнения","Отметка готовности","Удаление задания","Экзамены","Кабинеты","Заметки","Закреплённые заметки","Посещаемость","Процент выполнения"]),
        ("Фокус и аналитика", "chart.bar.fill", ["6 таймеров фокуса","Пауза таймера","Прогресс сессии","Калькулятор цели","Нужный средний балл","Распределение 1–10","Ближайший экзамен","Предупреждение о заданиях","Контроль посещаемости","Дни до четверти"]),
        ("Персонализация", "paintpalette.fill", ["Светлая тема","Тёмная тема","Живой фон","Стеклянные карточки","Анимация запуска","Тактильный отклик","Анимация цифр","Цвета успеваемости","Настройка конца четверти","Версия и номер сборки"])
    ]
    var body: some View { NavigationStack { List { ForEach(Array(groups.enumerated()), id: \.offset) { _, group in Section { ForEach(Array(group.2.enumerated()), id: \.offset) { index, item in HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.mint); Text(item); Spacer(); Text("\(index+1)").font(.caption2).foregroundStyle(.tertiary) } } } header: { Label(group.0, systemImage: group.1) } } }.navigationTitle("60 возможностей").toolbar { Button("Готово") { dismiss() } } } }
}
