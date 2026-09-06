import SwiftUI

/// A shared, finite animation: list cells never run their own display timers.
struct ProgressRing: View {
    let progress: Double
    let color: Color
    var size: CGFloat = 96
    var lineWidth: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var fraction: Double { progress.isFinite ? min(1, max(0, progress)) : 0 }
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.12), lineWidth: lineWidth)
            Circle().trim(from: 0, to: appeared ? fraction : 0)
                .stroke(AngularGradient(colors: [color.opacity(0.55), color, color], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.frame(width: size, height: size)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.9), value: appeared)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9), value: fraction)
            .onAppear { appeared = true }
            .accessibilityHidden(true)
    }
}

struct OrbitMetric: View {
    let title: String
    let value: String
    let detail: String
    let progress: Double
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: progress, color: color)
                VStack(spacing: 5) {
                    Image(systemName: symbol).font(.caption.bold()).foregroundStyle(color)
                    Text(value).font(.system(.title3, design: .rounded, weight: .bold)).monospacedDigit()
                        .contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.65)
                }.frame(width: 76)
            }.padding(.top, 7)
            VStack(spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }.multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(17)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).stroke(color.opacity(0.13), lineWidth: 1) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title): \(value). \(detail)")
    }
}

struct OrbitBackdrop: View {
    var color: Color = AppTheme.violet
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [AppTheme.deepViolet, color.opacity(0.9), AppTheme.deepViolet], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().stroke(.white.opacity(0.09), lineWidth: 1).frame(width: 260, height: 260).offset(x: geometry.size.width * 0.38, y: -65)
                Circle().stroke(.white.opacity(0.08), lineWidth: 26).frame(width: 200, height: 200).offset(x: geometry.size.width * 0.38, y: -65)
                Circle().fill(AppTheme.cyan.opacity(0.22)).frame(width: 90, height: 90).offset(x: -geometry.size.width * 0.45, y: 90)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct RevealEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { appeared = true } }
    }
}

extension View {
    func revealOnAppear() -> some View { modifier(RevealEffect()) }
}

/// Static action artwork; only the native button press animates.
struct DashboardAction: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title3.bold()).foregroundStyle(color)
                .frame(width: 44, height: 44).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(AppTheme.border) }
            .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct FocusSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PremiumTitle(eyebrow: "Без спешки", title: "Одна задача за раз", icon: "timer")
                    Text("Выбери время, убери отвлекающие вещи и начни. После сессии дай себе немного отдохнуть.")
                        .foregroundStyle(.secondary)
                    FocusTimerCard()
                }.padding(24)
            }.background { AnimatedAppBackground() }
                .navigationTitle("Фокус").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}

struct GradeDonut: View {
    let counts: [Int]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    private let colors = [AppTheme.mint, AppTheme.cyan, AppTheme.gold, AppTheme.coral]
    private var groups: [Int] { [8...10, 6...7, 4...5, 1...3].map { range in range.reduce(0) { $0 + (counts.indices.contains($1) ? counts[$1] : 0) } } }
    private var total: Int { groups.reduce(0, +) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.06), lineWidth: 14)
            ForEach(0..<4) { index in
                let start = Double(groups.prefix(index).reduce(0, +)) / Double(max(1, total))
                let end = Double(groups.prefix(index + 1).reduce(0, +)) / Double(max(1, total))
                Circle().trim(from: start, to: appeared ? max(start, end - min(0.012, (end - start) / 3)) : start)
                    .stroke(colors[index], style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 3) {
                Text("\(total)").font(.system(.title, design: .rounded, weight: .bold)).contentTransition(.numericText())
                Text("оценок").font(.caption2).foregroundStyle(.secondary)
            }
        }.frame(width: 106, height: 106).padding(7)
            .onAppear { appeared = true }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: appeared)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: counts)
            .accessibilityElement(children: .ignore).accessibilityLabel("Всего оценок: \(total)")
    }
}
