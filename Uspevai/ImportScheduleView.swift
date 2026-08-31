import SwiftUI
import PhotosUI
import Vision
import UIKit

struct ImportScheduleView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var recognized = ""
    @State private var importedLessons: [Lesson] = []
    @State private var isReading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let image { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22)) }
                    else { Image(systemName: "text.viewfinder").font(.system(size: 58)).foregroundStyle(AppTheme.violet); Text("Выбери фото таблицы с расписанием").font(.title3.bold()) }
                    PhotosPicker(selection: $photo, matching: .images) { Label("Выбрать фотографию", systemImage: "photo").frame(maxWidth: .infinity).padding().background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white).fontWeight(.semibold) }
                    if isReading { ProgressView("Распознаю армянский и русский текст…") }
                    if !importedLessons.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Нашёл \(importedLessons.count) уроков").font(.headline)
                            ForEach(importedLessons) { lesson in
                                HStack { Text(dayName(lesson.weekday)).foregroundStyle(.secondary).frame(width: 30); Text(lesson.title); Spacer() }
                            }
                        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        Button("Заменить расписание") { store.replaceLessons(importedLessons); dismiss() }
                            .frame(maxWidth: .infinity).padding().background(AppTheme.mint, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white).fontWeight(.bold)
                    } else if !recognized.isEmpty {
                        TextEditor(text: $recognized).frame(minHeight: 180).padding(8).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        Text("Не удалось уверенно разобрать таблицу. Текст сохранён выше — попробуй более ровное фото при хорошем освещении.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding()
            }.navigationTitle("Импорт с фото").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } } }
                .onChange(of: photo) { _, item in Task { await recognize(item) } }
        }
    }

    private func recognize(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else { return }
        image = uiImage; isReading = true
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["hy-AM", "ru-RU", "en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
        let results = request.results ?? []
        recognized = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        importedLessons = parse(results)
        isReading = false
    }

    private func parse(_ observations: [VNRecognizedTextObservation]) -> [Lesson] {
        let translations: [(String, String)] = [
            ("պատմություն", "История"), ("օպերացիոն համակարգեր", "Операционные системы"),
            ("ռուսաց լեզու", "Русский язык"), ("համակարգչային ճարտարապետություն", "Архитектура компьютера"),
            ("մաթ", "Основы математического анализа"), ("անվտանգություն", "Безопасность и первая помощь"),
            ("անգլերեն", "Английский язык"), ("ալգորիթմների", "Применение элементов алгоритмов"),
            ("հայոց լեզու", "Армянский язык и культура речи"), ("ֆիզկուլտուրա", "Физкультура"),
            ("էկոլոգիայի", "Основы экологии и природопользования")
        ]
        var found: [(day: Int, y: CGFloat, title: String)] = []
        for observation in observations {
            guard let raw = observation.topCandidates(1).first?.string.lowercased(),
                  let title = translations.first(where: { raw.contains($0.0) })?.1 else { continue }
            let centerX = observation.boundingBox.midX
            let day = min(6, max(2, Int(centerX * 5) + 2))
            found.append((day, observation.boundingBox.midY, title))
        }
        var output: [Lesson] = []
        for day in 2...6 {
            let unique = found.filter { $0.day == day }.sorted { $0.y > $1.y }.reduce(into: [String]()) { list, item in
                if !list.contains(item.title) { list.append(item.title) }
            }
            for (index, title) in unique.prefix(4).enumerated() {
                output.append(Lesson(weekday: day, order: index + 1, title: title,
                                     startsAt: SeedData.times[index].0, endsAt: SeedData.times[index].1))
            }
        }
        return output
    }

    private func dayName(_ weekday: Int) -> String { [2:"Пн", 3:"Вт", 4:"Ср", 5:"Чт", 6:"Пт"][weekday] ?? "" }
}
