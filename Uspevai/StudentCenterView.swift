import SwiftUI

struct StudentCenterView: View {
    @EnvironmentObject var store: AppStore
    @State private var targetGrade = 8
    @State private var futureGrades = 3
    @State private var showAllTools = false

    private var average: Double { store.study.average }
    private var homeworkProgress: Double { store.homework.isEmpty ? 0 : Double(store.study.completed) / Double(store.homework.count) }
    private var attendanceRate: Int { store.attendance.isEmpty ? 100 : Int(Double(store.study.present) / Double(store.attendance.count) * 100) }
    private var nextExam: Exam? { store.exams.filter { $0.date >= Date() }.sorted { $0.date < $1.date }.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    header
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        OrbitMetric(title: "Средний балл", value: store.grades.isEmpty ? "—" : String(format: "%.1f", average), detail: "из 10 баллов", progress: average / 10, symbol: "star.fill", color: AppTheme.gold)
                        OrbitMetric(title: "Посещение", value: store.attendance.isEmpty ? "—" : "\(attendanceRate)%", detail: "\(store.study.present) занятий", progress: store.attendance.isEmpty ? 0 : Double(attendanceRate) / 100, symbol: "person.fill.checkmark", color: AppTheme.cyan)
                        OrbitMetric(title: "Задания", value: "\(Int(homeworkProgress * 100))%", detail: "\(store.study.completed) выполнено", progress: homeworkProgress, symbol: "checkmark", color: AppTheme.mint)
                        OrbitMetric(title: "Высший балл", value: "\(store.study.excellent)", detail: "оценок 9 и 10", progress: store.grades.isEmpty ? 0 : Double(store.study.excellent) / Double(store.grades.count), symbol: "crown.fill", color: AppTheme.violet)
                    }
                    quickLinks
                    FocusTimerCard()
                    targetCalculator
                    gradeDistribution
                    smartFeed
                    Button { showAllTools = true } label: { Label("Возможности приложения", systemImage: "sparkles.rectangle.stack.fill").font(.headline).frame(maxWidth: .infinity).padding().foregroundStyle(.white).background(LinearGradient(colors: [AppTheme.violet, AppTheme.blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(ScalePressStyle())
                }.padding()
            }.background { AnimatedAppBackground() }.navigationTitle("Центр ученика")
                .sheet(isPresented: $showAllTools) { AllToolsView() }
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

    private var targetCalculator: some View {
        SoftCard { VStack(alignment: .leading, spacing: 13) { Label("Калькулятор цели", systemImage: "target").font(.headline); HStack { Stepper("Цель: \(targetGrade)", value: $targetGrade, in: 1...10); Stepper("Оценок: \(futureGrades)", value: $futureGrades, in: 1...20) }; Divider(); HStack { VStack(alignment: .leading) { Text("Нужный средний").font(.caption).foregroundStyle(.secondary); Text(requiredAverageText).font(.title2.bold()).foregroundStyle(requiredAverage > 10 ? AppTheme.coral : AppTheme.mint) }; Spacer(); Image(systemName: requiredAverage > 10 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill").font(.largeTitle).foregroundStyle(requiredAverage > 10 ? AppTheme.coral : AppTheme.mint) } } }
    }

    private var gradeDistribution: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Палитра успеваемости", subtitle: "Как распределились твои оценки")
                HStack(spacing: 24) {
                    GradeDonut(counts: store.study.gradeCounts)
                    VStack(alignment: .leading, spacing: 14) {
                        distributionLegend("Отлично · 8–10", range: 8...10, color: AppTheme.mint)
                        distributionLegend("Хорошо · 6–7", range: 6...7, color: AppTheme.cyan)
                        distributionLegend("Растём · 4–5", range: 4...5, color: AppTheme.gold)
                        distributionLegend("Подтянуть · 1–3", range: 1...3, color: AppTheme.coral)
                    }
                }
                if store.grades.isEmpty { Text("Добавь первую оценку — здесь появится твой прогресс.").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private func distributionLegend(_ title: String, range: ClosedRange<Int>, color: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.caption)
            Spacer(minLength: 0)
            Text("\(range.reduce(0) { $0 + store.study.gradeCounts[$1] })").font(.caption.bold()).monospacedDigit()
        }
    }

    private var smartFeed: some View {
        VStack(alignment: .leading, spacing: 12) { Text("Важно сейчас").font(.title3.bold()); if let exam = nextExam { info("Ближайшее: \(exam.title)", "\(exam.subject) • \(exam.date.formatted(date: .abbreviated, time: .shortened))", "calendar.badge.exclamationmark", AppTheme.coral) }; let undone = store.homework.filter { !$0.isDone }.count; info(undone == 0 ? "Все задания выполнены" : "Осталось заданий: \(undone)", undone == 0 ? "Отличная работа" : "Начни с ближайшего срока", undone == 0 ? "checkmark.seal.fill" : "list.bullet.clipboard", undone == 0 ? AppTheme.mint : AppTheme.violet); if attendanceRate < 80 { info("Посещаемость ниже 80%", "Старайся не пропускать уроки", "person.crop.circle.badge.exclamationmark", AppTheme.coral) } }
    }

    private func metric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View { SoftCard { VStack(alignment: .leading, spacing: 9) { Image(systemName: icon).foregroundStyle(color).font(.title3); Text(value).font(.title2.bold()).contentTransition(.numericText()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
    private func quick(_ title: String, _ icon: String, _ color: Color) -> some View { VStack(spacing: 8) { Image(systemName: icon).font(.title2).foregroundStyle(.white).frame(width: 48, height: 48).background(color.gradient, in: RoundedRectangle(cornerRadius: 15)); Text(title).font(.caption.bold()).foregroundStyle(.primary) }.frame(maxWidth: .infinity) }
    private func info(_ title: String, _ subtitle: String, _ icon: String, _ color: Color) -> some View { SoftCard { HStack(spacing: 13) { Image(systemName: icon).font(.title2).foregroundStyle(color).frame(width: 38); VStack(alignment: .leading) { Text(title).font(.subheadline.bold()); Text(subtitle).font(.caption).foregroundStyle(.secondary) }; Spacer() } } }
    private func weightedAverage(_ values: [Grade]) -> Double { let weights = values.map { $0.weight ?? 1 }.reduce(0,+); return weights == 0 ? 0 : Double(values.map { $0.value * ($0.weight ?? 1) }.reduce(0,+))/Double(weights) }
    private var requiredAverage: Double { (Double(targetGrade * (store.study.totalWeight + futureGrades)) - average * Double(store.study.totalWeight)) / Double(max(1, futureGrades)) }
    private var requiredAverageText: String { requiredAverage > 10 ? "Выше 10 — измени цель" : String(format: "%.2f из 10", max(1,requiredAverage)) }
    private var daysToTerm: Int { max(0, Calendar.current.dateComponents([.day], from: Date(), to: store.termEnd).day ?? 0) }
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
    var body: some View { NavigationStack { List { ForEach(Array(groups.enumerated()), id: \.offset) { _, group in Section { ForEach(Array(group.2.enumerated()), id: \.offset) { index, item in HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.mint); Text(item); Spacer(); Text("\(index+1)").font(.caption2).foregroundStyle(.tertiary) } } } header: { Label(group.0, systemImage: group.1) } } }.navigationTitle("Возможности").toolbar { Button("Готово") { dismiss() } } } }
}
