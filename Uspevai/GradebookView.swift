import SwiftUI

struct GradebookView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAdd = false
    @State private var selectedSubject = "Все предметы"
    @State private var query = ""
    @State private var mode = 0
    @State private var selectedGrade: Grade?

    private var subjects: [String] {
        Array(Set(store.lessons.map(\.title) + store.grades.map(\.subject))).sorted()
    }
    private var dates: [Date] {
        let calendar = Calendar.current
        return Array(Set(store.grades.filter { $0.date <= store.termEnd }.map { calendar.startOfDay(for: $0.date) })).sorted()
    }
    private var visibleSubjects: [String] {
        let base = selectedSubject == "Все предметы" ? subjects : [selectedSubject]
        return query.isEmpty ? base : base.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
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
                .searchable(text: $query, prompt: "Найти предмет")
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
