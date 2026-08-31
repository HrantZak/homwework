import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: AppStore
    @State private var day = 2
    @State private var showImport = false
    private let days = [(2,"Пн"),(3,"Вт"),(4,"Ср"),(5,"Чт"),(6,"Пт")]

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 7) {
                    ForEach(days, id: \.0) { value, label in
                        Button(label) { withAnimation(.snappy) { day = value } }
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 11)
                            .foregroundStyle(day == value ? .white : .primary)
                            .background(day == value ? AppTheme.violet : Color.clear, in: Capsule())
                    }
                }.padding(5).background(.thinMaterial, in: Capsule()).padding(.horizontal)
                ScrollView {
                    LazyVStack(spacing: 13) {
                        ForEach(store.lessons.filter { $0.weekday == day }.sorted { $0.order < $1.order }) { lesson in
                            NavigationLink { LessonEditor(lessonID: lesson.id) } label: { LessonRow(lesson: lesson) }.buttonStyle(.plain)
                        }
                    }.padding()
                }
            }.background(AppTheme.background).navigationTitle("Расписание")
                .toolbar { Button { showImport = true } label: { Label("Импорт", systemImage: "camera.viewfinder") } }
                .sheet(isPresented: $showImport) { ImportScheduleView() }
        }
    }
}

struct LessonEditor: View {
    @EnvironmentObject var store: AppStore
    let lessonID: UUID
    var index: Int? { store.lessons.firstIndex { $0.id == lessonID } }
    var body: some View {
        Form {
            if let index {
                TextField("Предмет", text: $store.lessons[index].title)
                TextField("Преподаватель", text: $store.lessons[index].teacher)
                TextField("Начало", text: $store.lessons[index].startsAt).keyboardType(.numbersAndPunctuation)
                TextField("Конец", text: $store.lessons[index].endsAt).keyboardType(.numbersAndPunctuation)
            }
        }.navigationTitle("Урок").navigationBarTitleDisplayMode(.inline)
    }
}
