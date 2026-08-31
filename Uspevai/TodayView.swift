import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var heroMoves = false
    private var weekday: Int { Calendar.current.component(.weekday, from: Date()) }
    private var today: [Lesson] { store.lessons.filter { $0.weekday == weekday }.sorted { $0.order < $1.order } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [AppTheme.violet, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Circle().fill(.white.opacity(0.13)).frame(width: 180).offset(x: heroMoves ? 210 : 250, y: heroMoves ? -35 : -70).blur(radius: heroMoves ? 1 : 7)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.subheadline).opacity(0.8)
                            Text(today.isEmpty ? "Сегодня можно выдохнуть" : "Сегодня \(today.count) урока").font(.system(size: 29, weight: .bold, design: .rounded))
                            Text("Всё важное — в одном месте").opacity(0.82)
                        }.foregroundStyle(.white).padding(24)
                    }.frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).shadow(color: AppTheme.violet.opacity(0.25), radius: 24, y: 12).onAppear { withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { heroMoves = true } }

                    Text("Твой день").font(.title2.bold())
                    if today.isEmpty { ContentUnavailableView("Уроков нет", systemImage: "sun.max", description: Text("Посмотри задания или отдохни")) }
                    ForEach(today) { lesson in LessonRow(lesson: lesson) }
                }.padding()
            }.background { AnimatedAppBackground() }.navigationTitle("Успевай")
        }
    }
}

struct LessonRow: View {
    let lesson: Lesson
    var body: some View {
        SoftCard {
            HStack(spacing: 15) {
                VStack { Text(lesson.startsAt).font(.headline); Text(lesson.endsAt).font(.caption).foregroundStyle(.secondary) }
                Capsule().fill(AppTheme.violet.gradient).frame(width: 5, height: 46)
                VStack(alignment: .leading, spacing: 4) { Text(lesson.title).font(.headline); if !lesson.teacher.isEmpty { Text(lesson.teacher).font(.caption).foregroundStyle(.secondary) } }
                Spacer()
                Text("\(lesson.order)").font(.caption.bold()).foregroundStyle(AppTheme.violet).padding(8).background(AppTheme.violet.opacity(0.12), in: Circle())
            }
        }.transition(.move(edge: .bottom).combined(with: .opacity)).contentShape(RoundedRectangle(cornerRadius: 25)).hoverEffect(.lift)
    }
}
