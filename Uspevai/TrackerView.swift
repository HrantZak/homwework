import SwiftUI

struct TrackerView: View {
    @EnvironmentObject var store: AppStore
    @State private var addGrade = false
    @State private var addExam = false
    @State private var addNote = false
    @State private var addAttendance = false
    @State private var focusSeconds = 25 * 60
    @State private var focusing = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var average: Double {
        guard !store.grades.isEmpty else { return 0 }
        return Double(store.grades.map(\.value).reduce(0,+)) / Double(store.grades.count)
    }
    private var attendanceRate: Int {
        guard !store.attendance.isEmpty else { return 100 }
        return Int(Double(store.attendance.filter(\.wasPresent).count) / Double(store.attendance.count) * 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        stat("Средний балл", average == 0 ? "—" : String(format: "%.1f", average), "star.fill", AppTheme.coral)
                        stat("Посещение", "\(attendanceRate)%", "person.fill.checkmark", AppTheme.mint)
                    }
                    SoftCard {
                        VStack(spacing: 12) {
                            HStack { Label("Фокус", systemImage: "timer").font(.headline); Spacer(); Text(String(format: "%02d:%02d", focusSeconds/60, focusSeconds%60)).font(.title2.monospacedDigit().bold()) }
                            ProgressView(value: Double(25*60-focusSeconds), total: Double(25*60)).tint(AppTheme.violet)
                            HStack { Button(focusing ? "Пауза" : "Начать") { focusing.toggle() }.buttonStyle(.borderedProminent).tint(AppTheme.violet); Button("Сбросить") { focusing = false; focusSeconds = 25*60 }.buttonStyle(.bordered) }
                        }
                    }
                    sectionTitle("Ближайшие экзамены", action: { addExam = true })
                    if store.exams.isEmpty { emptyCard("Добавь контрольную или экзамен", "calendar.badge.plus") }
                    ForEach(store.exams.sorted { $0.date < $1.date }.prefix(4)) { exam in
                        SoftCard { HStack { VStack(alignment: .leading) { Text(exam.title).font(.headline); Text(exam.subject).foregroundStyle(.secondary) }; Spacer(); Text(exam.date.formatted(.dateTime.day().month(.abbreviated))).font(.subheadline.bold()).foregroundStyle(AppTheme.violet) } }
                    }
                    sectionTitle("Последние оценки", action: { addGrade = true })
                    if store.grades.isEmpty { emptyCard("Добавь первую оценку", "star.circle") }
                    ForEach(store.grades.sorted { $0.date > $1.date }.prefix(5)) { grade in
                        SoftCard { HStack { Text("\(grade.value)").font(.title.bold()).foregroundStyle(grade.value >= 4 ? AppTheme.mint : AppTheme.coral).frame(width: 44); VStack(alignment: .leading) { Text(grade.subject).font(.headline); Text(grade.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }; Spacer() } }
                    }
                    sectionTitle("Заметки", action: { addNote = true })
                    ForEach(store.notes.sorted { $0.isPinned && !$1.isPinned }) { note in
                        SoftCard { VStack(alignment: .leading, spacing: 7) { HStack { Text(note.title).font(.headline); if note.isPinned { Image(systemName: "pin.fill").foregroundStyle(AppTheme.coral) } }; Text(note.text).foregroundStyle(.secondary).lineLimit(3) }.frame(maxWidth: .infinity, alignment: .leading) }
                    }
                }.padding()
            }.background(AppTheme.background).navigationTitle("Мой прогресс")
                .toolbar { Menu { Button("Оценку", systemImage: "star") { addGrade = true }; Button("Посещение", systemImage: "person.fill.checkmark") { addAttendance = true }; Button("Экзамен", systemImage: "calendar") { addExam = true }; Button("Заметку", systemImage: "note.text") { addNote = true } } label: { Image(systemName: "plus") } }
                .sheet(isPresented: $addGrade) { AddGradeView() }
                .sheet(isPresented: $addExam) { AddExamView() }
                .sheet(isPresented: $addNote) { AddNoteView() }
                .sheet(isPresented: $addAttendance) { AddAttendanceView() }
                .onReceive(timer) { _ in if focusing && focusSeconds > 0 { focusSeconds -= 1 } else if focusSeconds == 0 { focusing = false } }
        }
    }
    private func stat(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View { SoftCard { VStack(alignment: .leading, spacing: 10) { Image(systemName: icon).foregroundStyle(color); Text(value).font(.title.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
    private func sectionTitle(_ title: String, action: @escaping () -> Void) -> some View { HStack { Text(title).font(.title3.bold()); Spacer(); Button(action: action) { Image(systemName: "plus.circle.fill").font(.title2) } } }
    private func emptyCard(_ text: String, _ icon: String) -> some View { SoftCard { Label(text, systemImage: icon).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) } }
}

struct AddAttendanceView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    @State var subject = ""; @State var date = Date(); @State var present = true
    var body: some View { NavigationStack { Form { TextField("Предмет", text: $subject); DatePicker("Дата", selection: $date, displayedComponents: .date); Toggle("Присутствовал", isOn: $present) }.navigationTitle("Посещение").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Добавить") { store.attendance.append(Attendance(subject: subject, date: date, wasPresent: present)); dismiss() }.disabled(subject.isEmpty) } } } }
}

struct AddGradeView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    @State var subject = ""; @State var value = 5; @State var note = ""
    var body: some View { NavigationStack { Form { TextField("Предмет", text: $subject); Picker("Оценка", selection: $value) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }; TextField("Комментарий", text: $note) }.navigationTitle("Новая оценка").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Добавить") { store.grades.append(Grade(subject: subject, value: value, note: note)); dismiss() }.disabled(subject.isEmpty) } } } }
}

struct AddExamView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    @State var title = "Контрольная"; @State var subject = ""; @State var date = Date().addingTimeInterval(604800); @State var room = ""
    var body: some View { NavigationStack { Form { TextField("Название", text: $title); TextField("Предмет", text: $subject); DatePicker("Дата", selection: $date); TextField("Кабинет", text: $room) }.navigationTitle("Экзамен").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Добавить") { store.exams.append(Exam(title: title, subject: subject, date: date, room: room)); dismiss() }.disabled(subject.isEmpty) } } } }
}

struct AddNoteView: View {
    @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss
    @State var title = ""; @State var text = ""; @State var pinned = false
    var body: some View { NavigationStack { Form { TextField("Заголовок", text: $title); TextField("Текст", text: $text, axis: .vertical).lineLimit(4...10); Toggle("Закрепить", isOn: $pinned) }.navigationTitle("Заметка").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { store.notes.append(SchoolNote(title: title, text: text, isPinned: pinned)); dismiss() }.disabled(title.isEmpty) } } } }
}
