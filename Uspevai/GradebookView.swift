import SwiftUI

struct GradeCalendar: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let gradedDates: [Date]
    private let calendar = Calendar.current
    private let headers = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    private var monthStart: Date { calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))! }
    private var cells: [Date?] {
        let count = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday + 5) % 7
        return Array(repeating: nil, count: leading) + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: monthStart) }
    }

    var body: some View {
        SoftCard {
            VStack(spacing: 14) {
                HStack {
                    Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 38, height: 38).background(.primary.opacity(0.06), in: Circle()) }.buttonStyle(ScalePressStyle())
                    Spacer()
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year())).font(.title3.bold()).contentTransition(.numericText())
                    Spacer()
                    Button { changeMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 38, height: 38).background(.primary.opacity(0.06), in: Circle()) }.buttonStyle(ScalePressStyle())
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 8) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                        Text(header).font(.system(size: 10, weight: .heavy)).foregroundStyle(index >= 5 ? .secondary.opacity(0.65) : AppTheme.violet)
                    }
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                        if let date { dayCell(date) } else { Color.clear.frame(height: 43) }
                    }
                }
                HStack(spacing: 15) { Label("Есть оценка", systemImage: "circle.fill").foregroundStyle(AppTheme.mint); Label("Выходной", systemImage: "circle.fill").foregroundStyle(.gray.opacity(0.55)); Spacer() }.font(.caption2)
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let weekday = calendar.component(.weekday, from: date)
        let weekend = weekday == 1 || weekday == 7
        let graded = gradedDates.contains { calendar.isDate($0, inSameDayAs: date) }
        let selected = calendar.isDate(selectedDate, inSameDayAs: date)
        let today = calendar.isDateInToday(date)
        return Button {
            guard !weekend else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedDate = date }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? AppTheme.violet : weekend ? Color.gray.opacity(0.13) : graded ? AppTheme.mint.opacity(0.16) : Color.primary.opacity(0.035))
                if graded && !selected { RoundedRectangle(cornerRadius: 12).stroke(AppTheme.mint.opacity(0.65), lineWidth: 1.5) }
                if today && !selected { RoundedRectangle(cornerRadius: 12).stroke(AppTheme.violet, lineWidth: 1.5) }
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))").font(.subheadline.bold())
                    Circle().fill(graded ? (selected ? Color.white : AppTheme.mint) : Color.clear).frame(width: 4, height: 4)
                }.foregroundStyle(selected ? .white : weekend ? .secondary.opacity(0.55) : .primary)
            }.frame(height: 43)
        }.buttonStyle(.plain).disabled(weekend).accessibilityLabel(date.formatted(date: .long, time: .omitted))
    }

    private func changeMonth(_ amount: Int) {
        let nextMonth = calendar.date(byAdding: .month, value: amount, to: monthStart)!
        let candidate = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))!
        let weekday = calendar.component(.weekday, from: candidate)
        withAnimation(.snappy) {
            displayedMonth = nextMonth
            selectedDate = (weekday == 1 || weekday == 7) ? calendar.date(byAdding: .day, value: weekday == 7 ? 2 : 1, to: candidate)! : candidate
        }
    }
}

struct GradebookView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAdd = false
    @State private var selectedSubject = "Все предметы"
    @State private var query = ""
    @State private var mode = 0
    @State private var selectedGrade: Grade?
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var gradingLesson: Lesson?

    private var subjects: [String] {
        Array(Set(store.lessons.map(\.title) + store.grades.map(\.subject))).sorted()
    }
    private var dates: [Date] {
        let calendar = Calendar.current
        return Array(Set(store.grades.filter { $0.date <= store.termEnd && calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }.map { calendar.startOfDay(for: $0.date) })).sorted()
    }
    private var visibleSubjects: [String] {
        let base = selectedSubject == "Все предметы" ? subjects : [selectedSubject]
        return query.isEmpty ? base : base.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PremiumTitle(eyebrow: "Учебный месяц", title: "Календарь оценок", icon: "calendar.badge.checkmark")
                    GradeCalendar(displayedMonth: $displayedMonth, selectedDate: $selectedDate, gradedDates: store.grades.map(\.date))
                    selectedDayCard
                    summary
                    Picker("Предмет", selection: $selectedSubject) {
                        Text("Все предметы").tag("Все предметы")
                        ForEach(subjects, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Вид", selection: $mode) { Label("Таблица", systemImage: "tablecells").tag(0); Label("Карточки", systemImage: "rectangle.grid.1x2").tag(1) }.pickerStyle(.segmented)

                    if store.grades.isEmpty {
                        ContentUnavailableView("Журнал пуст", systemImage: "tablecells", description: Text("Нажми + и добавь первую оценку"))
                    } else {
                        if mode == 0 { gradeTable } else { subjectCards }
                        legend
                    }
                }.padding()
            }.background { AnimatedAppBackground() }.navigationTitle("Журнал оценок")
                .toolbar { Button { showAdd = true } label: { Label("Добавить", systemImage: "plus") } }
                .sheet(isPresented: $showAdd) { AddGradeView() }
                .sheet(item: $selectedGrade) { GradeDetailView(grade: $0) }
                .sheet(item: $gradingLesson) { AddLessonGradeView(lesson: $0, date: selectedDate) }
                .searchable(text: $query, prompt: "Найти предмет")
        }
    }

    private var selectedDayCard: some View {
        let weekday = Calendar.current.component(.weekday, from: selectedDate)
        let lessons = store.lessons.filter { $0.weekday == weekday }.sorted { $0.order < $1.order }
        return SoftCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) { Text("Расписание на день").font(.headline); Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Text("\(lessons.count) урока").font(.caption.bold()).foregroundStyle(AppTheme.violet).padding(.horizontal, 10).padding(.vertical, 6).background(AppTheme.violet.opacity(0.1), in: Capsule())
                }
                if lessons.isEmpty { Label("Уроков нет", systemImage: "moon.stars").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8) }
                ForEach(lessons) { lesson in
                    HStack(spacing: 11) {
                        Text("\(lesson.order)").font(.caption.bold()).foregroundStyle(.secondary).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) { Text(lesson.title).font(.subheadline.bold()).lineLimit(2); Text("\(lesson.startsAt)–\(lesson.endsAt)").font(.caption2).foregroundStyle(.secondary) }
                        Spacer()
                        Button { gradingLesson = lesson } label: {
                            let grade = gradeFor(lesson)
                            Text(grade.map(String.init) ?? "+").font(.headline.bold()).foregroundStyle(grade == nil ? AppTheme.violet : .white).frame(width: 43, height: 43).background(grade == nil ? AppTheme.violet.opacity(0.1) : gradeColor(grade!), in: RoundedRectangle(cornerRadius: 12)).overlay { RoundedRectangle(cornerRadius: 12).stroke(AppTheme.violet.opacity(grade == nil ? 0.25 : 0), lineWidth: 1) }
                        }.buttonStyle(ScalePressStyle())
                    }
                    if lesson.id != lessons.last?.id { Divider().padding(.leading, 33) }
                }
            }
        }
    }

    private var summary: some View {
        let average = weightedAverage(store.grades)
        return HStack(spacing: 12) {
            summaryCard("Оценок", "\(store.grades.count)", "number.circle.fill", AppTheme.violet)
            summaryCard("Средний", average == 0 ? "—" : String(format: "%.2f", average), "chart.line.uptrend.xyaxis", AppTheme.mint)
            summaryCard("До 26.12", "\(max(0, Calendar.current.dateComponents([.day], from: Date(), to: store.termEnd).day ?? 0))", "calendar", AppTheme.coral)
        }
    }

    private var gradeTable: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    tableCell("Предмет", width: 155, header: true)
                    ForEach(dates, id: \.self) { date in tableCell(date.formatted(.dateTime.day().month(.twoDigits)), width: 58, header: true) }
                    tableCell("Ср.", width: 58, header: true)
                    tableCell("Итог", width: 62, header: true)
                }
                ForEach(Array(visibleSubjects.enumerated()), id: \.element) { index, subject in
                    GridRow {
                        tableCell(subject, width: 155, shaded: index.isMultiple(of: 2))
                        ForEach(dates, id: \.self) { date in
                            gradeCell(subject: subject, date: date, shaded: index.isMultiple(of: 2))
                        }
                        let grades = store.grades.filter { $0.subject == subject }
                        let avg = weightedAverage(grades)
                        tableCell(grades.isEmpty ? "—" : String(format: "%.1f", avg), width: 58, shaded: index.isMultiple(of: 2), strong: true)
                        tableCell(grades.isEmpty ? "—" : "\(min(10,max(1,Int(avg.rounded()))))", width: 62, shaded: index.isMultiple(of: 2), strong: true)
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.08)))
        }
    }

    private func gradeCell(subject: String, date: Date, shaded: Bool) -> some View {
        let grade = store.grades.first { $0.subject == subject && Calendar.current.isDate($0.date, inSameDayAs: date) }
        return Button { if let grade { selectedGrade = grade } } label: { ZStack {
            Rectangle().fill(shaded ? Color.primary.opacity(0.035) : Color(uiColor: .secondarySystemGroupedBackground))
            if let grade { Text("\(grade.value)").font(.headline.bold()).foregroundStyle(.white).frame(width: 34, height: 34).background(gradeColor(grade.value), in: Circle()).contentTransition(.numericText()).symbolEffect(.bounce, value: grade.value) }
            else { Text("·").foregroundStyle(.tertiary) }
        }.frame(width: 58, height: 58).overlay(alignment: .leading) { Divider() } }.buttonStyle(.plain)
    }

    private var subjectCards: some View {
        VStack(spacing: 13) {
            ForEach(visibleSubjects, id: \.self) { subject in
                let grades = store.grades.filter { $0.subject == subject }.sorted { $0.date > $1.date }
                let avg = weightedAverage(grades)
                SoftCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { VStack(alignment: .leading) { Text(subject).font(.headline); Text("\(grades.count) оценок • средний \(grades.isEmpty ? "—" : String(format: "%.2f", avg))").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(grades.isEmpty ? "—" : "\(min(10,max(1,Int(avg.rounded()))))").font(.title.bold()).foregroundStyle(gradeColor(Int(avg.rounded()))) }
                        ProgressView(value: min(10, avg), total: 10).tint(gradeColor(Int(avg.rounded())))
                        ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(grades) { grade in Button { selectedGrade = grade } label: { VStack { Text("\(grade.value)").font(.headline); Text(grade.date.formatted(.dateTime.day().month(.twoDigits))).font(.caption2) }.foregroundStyle(.white).frame(width: 48, height: 52).background(gradeColor(grade.value), in: RoundedRectangle(cornerRadius: 13)) }.buttonStyle(.plain) } } }
                    }
                }
            }
        }
    }

    private func weightedAverage(_ grades: [Grade]) -> Double {
        guard !grades.isEmpty else { return 0 }
        let totalWeight = grades.map { $0.weight ?? 1 }.reduce(0,+)
        let points = grades.map { $0.value * ($0.weight ?? 1) }.reduce(0,+)
        return totalWeight == 0 ? 0 : Double(points) / Double(totalWeight)
    }
    private func gradeFor(_ lesson: Lesson) -> Int? { store.grades.first { $0.lessonID == lesson.id && Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }?.value }

    private func tableCell(_ text: String, width: CGFloat, header: Bool = false, shaded: Bool = false, strong: Bool = false) -> some View {
        Text(text).font(header || strong ? .caption.bold() : .caption).lineLimit(2).frame(width: width, height: header ? 48 : 58, alignment: width > 100 ? .leading : .center).padding(.horizontal, width > 100 ? 10 : 0)
            .background(header ? AppTheme.violet.opacity(0.14) : shaded ? Color.primary.opacity(0.035) : Color(uiColor: .secondarySystemGroupedBackground)).overlay(alignment: .leading) { Divider() }
    }
    private func summaryCard(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View { VStack(spacing: 7) { Image(systemName: icon).foregroundStyle(color); Text(value).font(.title3.bold()); Text(title).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)) }
    private var legend: some View { HStack { legendItem(10,"Отлично"); legendItem(8,"Хорошо"); legendItem(6,"Средне"); legendItem(3,"Нужно подтянуть") }.font(.caption2).frame(maxWidth: .infinity) }
    private func legendItem(_ value: Int, _ text: String) -> some View { HStack(spacing: 4) { Circle().fill(gradeColor(value)).frame(width: 8); Text(text) } }
    private func gradeColor(_ value: Int) -> Color { value >= 8 ? AppTheme.mint : value >= 6 ? .blue : value >= 4 ? .orange : AppTheme.coral }
}

struct GradeDetailView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    let grade: Grade
    var body: some View {
        NavigationStack {
            List {
                Section { HStack { Spacer(); VStack { Text("\(grade.value)").font(.system(size: 58, weight: .bold, design: .rounded)); Text("из 10").font(.caption).foregroundStyle(.secondary) }.foregroundStyle(grade.value >= 8 ? AppTheme.mint : grade.value >= 4 ? .orange : AppTheme.coral); Spacer() } }
                Section("Информация") { LabeledContent("Предмет", value: grade.subject); LabeledContent("Дата", value: grade.date.formatted(date: .long, time: .omitted)); LabeledContent("Тип", value: grade.category ?? "Обычная работа"); LabeledContent("Вес", value: "×\(grade.weight ?? 1)"); if !grade.note.isEmpty { LabeledContent("Комментарий", value: grade.note) } }
                Section { Button("Удалить оценку", role: .destructive) { store.grades.removeAll { $0.id == grade.id }; dismiss() } }
            }.navigationTitle("Оценка").navigationBarTitleDisplayMode(.inline).toolbar { Button("Готово") { dismiss() } }
        }
    }
}
