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
                LazyVStack(spacing: 18) {
                    if let image { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22)) }
                    else { Image(systemName: "text.viewfinder").font(.system(size: 58)).foregroundStyle(AppTheme.violet); Text("Выбери фото таблицы с расписанием").font(.title3.bold()) }
                    PhotosPicker(selection: $photo, matching: .images) { Label("Выбрать фотографию", systemImage: "photo").frame(maxWidth: .infinity).padding().background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white).fontWeight(.semibold) }
                    if isReading { ProgressView("Распознаю армянский и русский текст…") }
                    if !importedLessons.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Нашёл \(importedLessons.count) уроков").font(.headline)
                            ForEach(importedLessons) { lesson in
                                HStack(spacing: 10) {
                                    Text(dayName(lesson.weekday)).foregroundStyle(.secondary).frame(width: 30)
                                    VStack(alignment: .leading, spacing: 2) { Text(lesson.title); Text("\(lesson.startsAt)–\(lesson.endsAt)").font(.caption.monospacedDigit()).foregroundStyle(AppTheme.violet) }
                                    Spacer()
                                }
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
        guard let data = try? await item?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) else { return }
        image = uiImage; isReading = true
        let blocks = await Task.detached(priority: .userInitiated) { () -> [RecognizedScheduleBlock] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["hy-AM", "ru-RU", "en-US"]
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.012
            let handler = VNImageRequestHandler(data: data)
            try? handler.perform([request])
            return (request.results ?? []).compactMap { observation in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                return RecognizedScheduleBlock(text: text, box: observation.boundingBox)
            }
        }.value
        recognized = blocks.sorted { $0.box.midY > $1.box.midY }.map(\.text).joined(separator: "\n")
        importedLessons = parse(blocks)
        isReading = false
    }

    private func parse(_ observations: [RecognizedScheduleBlock]) -> [Lesson] {
        let translations: [(String, String)] = [
            ("պատմություն", "История"), ("օպերացիոն համակարգեր", "Операционные системы"),
            ("ռուսաց լեզու", "Русский язык"), ("համակարգչային ճարտարապետություն", "Архитектура компьютера"),
            ("մաթ", "Основы математического анализа"), ("անվտանգություն", "Безопасность и первая помощь"),
            ("անգլերեն", "Английский язык"), ("ալգորիթմների", "Применение элементов алгоритмов"),
            ("հայոց լեզու", "Армянский язык и культура речи"), ("ֆիզկուլտուրա", "Физкультура"),
            ("էկոլոգիայի", "Основы экологии и природопользования")
        ]
        let timeRows = observations.compactMap { block -> (y: CGFloat, start: String, end: String)? in
            guard let range = parseTimeRange(block.text) else { return nil }
            return (block.box.midY, range.0, range.1)
        }.sorted { $0.y > $1.y }
        var found: [(day: Int, y: CGFloat, title: String)] = []
        for observation in observations {
            let raw = observation.text.lowercased()
            guard
                  let title = translations.first(where: { raw.contains($0.0) })?.1 else { continue }
            let centerX = observation.box.midX
            let column = Int(floor((centerX - 0.105) / 0.175))
            let day = min(6, max(2, column + 2))
            found.append((day, observation.box.midY, title))
        }
        var output: [Lesson] = []
        for day in 2...6 {
            let subjects = found.filter { $0.day == day }.sorted { $0.y > $1.y }
            var usedRows = Set<Int>()
            for item in subjects {
                let row = timeRows.enumerated().min { abs($0.element.y - item.y) < abs($1.element.y - item.y) }
                let fallbackIndex = min(SeedData.times.count - 1, usedRows.count)
                let rowIndex = row?.offset ?? fallbackIndex
                guard !usedRows.contains(rowIndex) else { continue }
                usedRows.insert(rowIndex)
                let interval = row.map { ($0.element.start, $0.element.end) } ?? SeedData.times[fallbackIndex]
                output.append(Lesson(weekday: day, order: rowIndex + 1, title: item.title, startsAt: interval.0, endsAt: interval.1))
            }
        }
        return output.sorted { ($0.weekday, $0.order) < ($1.weekday, $1.order) }
    }

    private func parseTimeRange(_ text: String) -> (String, String)? {
        let normalized = text.replacingOccurrences(of: ".", with: ":")
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2}:\d{2})\s*[-–—]\s*(\d{1,2}:\d{2})"#),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              let first = Range(match.range(at: 1), in: normalized), let second = Range(match.range(at: 2), in: normalized) else { return nil }
        return (String(normalized[first]), String(normalized[second]))
    }

    private func dayName(_ weekday: Int) -> String { [2:"Пн", 3:"Вт", 4:"Ср", 5:"Чт", 6:"Пт"][weekday] ?? "" }
}

private struct RecognizedScheduleBlock: Sendable {
    let text: String
    let box: CGRect
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
