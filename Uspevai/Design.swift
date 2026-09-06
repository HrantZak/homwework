import SwiftUI

enum AppTheme {
    static let violet = Color(red: 0.38, green: 0.24, blue: 0.96)
    static let deepViolet = Color(red: 0.075, green: 0.09, blue: 0.23)
    static let coral = Color(red: 1.0, green: 0.38, blue: 0.39)
    static let mint = Color(red: 0.10, green: 0.76, blue: 0.61)
    static let cyan = Color(red: 0.12, green: 0.68, blue: 0.98)
    static let gold = Color(red: 1.0, green: 0.68, blue: 0.16)
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.045, green: 0.055, blue: 0.10, alpha: 1) : UIColor(red: 0.955, green: 0.96, blue: 0.985, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.09, green: 0.105, blue: 0.17, alpha: 1) : .white
    })
    static let border = Color.primary.opacity(0.075)
    static let blue = Color(red: 0.10, green: 0.43, blue: 1.0)
    static let heroGradient = LinearGradient(colors: [deepViolet, violet, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let actionGradient = LinearGradient(colors: [violet, blue], startPoint: .leading, endPoint: .trailing)
}

struct SoftCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1).allowsHitTesting(false) }
    }
}

struct AnimatedAppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background
            LinearGradient(colors: [AppTheme.violet.opacity(0.055), .clear], startPoint: .topLeading, endPoint: .center)
        }.ignoresSafeArea()
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 11) {
            if let symbol {
                Image(systemName: symbol).font(.subheadline.bold()).foregroundStyle(AppTheme.violet)
                    .frame(width: 38, height: 38).background(AppTheme.violet.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.title3.bold())
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
        }.accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
}

struct StatusPill: View {
    let title: String
    let symbol: String
    var color: Color = AppTheme.violet

    var body: some View {
        Label(title, systemImage: symbol).font(.caption.bold()).foregroundStyle(color)
            .padding(.horizontal, 11).frame(height: 32).background(color.opacity(0.11), in: Capsule())
    }
}

struct PremiumTitle: View {
    let eyebrow: String; let title: String; let icon: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2.bold()).foregroundStyle(.white).frame(width: 50, height: 50).background(LinearGradient(colors: [AppTheme.violet, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous)).shadow(color: AppTheme.violet.opacity(0.25), radius: 12, y: 6)
            VStack(alignment: .leading, spacing: 2) { Text(eyebrow.uppercased()).font(.caption2.bold()).tracking(1.4).foregroundStyle(AppTheme.violet); Text(title).font(.title2.bold()) }
            Spacer()
        }
    }
}

struct ScalePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1).opacity(configuration.isPressed ? 0.86 : 1).animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed) }
}

struct FocusTimerCard: View {
    let presets: [Int]
    @State private var selectedMinutes: Int
    @State private var secondsLeft: Int
    @State private var isRunning = false
    @State private var deadline: Date?
    @Environment(\.scenePhase) private var scenePhase

    init(presets: [Int] = [15, 25, 40, 50, 60, 90], initial: Int = 25) {
        self.presets = presets
        let selected = presets.contains(initial) ? initial : (presets.first ?? initial)
        _selectedMinutes = State(initialValue: selected)
        _secondsLeft = State(initialValue: selected * 60)
    }

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Таймер фокуса", systemImage: "timer").font(.headline)
                    Spacer()
                    Text(clockText).font(.title2.monospacedDigit().bold()).foregroundStyle(AppTheme.violet).contentTransition(.numericText())
                }
                if presets.count > 1 {
                    HStack(spacing: 7) {
                        ForEach(presets, id: \.self) { value in
                            Button("\(value)") { select(value) }
                                .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(selectedMinutes == value ? AppTheme.violet : Color.primary.opacity(0.06), in: Capsule())
                                .foregroundStyle(selectedMinutes == value ? Color.white : Color.primary)
                                .buttonStyle(ScalePressStyle())
                        }
                    }
                }
                ProgressView(value: Double(selectedMinutes * 60 - secondsLeft), total: Double(max(1, selectedMinutes * 60))).tint(AppTheme.violet)
                HStack {
                    Button(isRunning ? "Пауза" : secondsLeft == 0 ? "Сначала" : "Начать") {
                        if secondsLeft == 0 { secondsLeft = selectedMinutes * 60 }
                        if isRunning {
                            if let deadline { secondsLeft = max(0, Int(ceil(deadline.timeIntervalSinceNow))) }
                            isRunning = false; deadline = nil
                        } else {
                            deadline = Date().addingTimeInterval(TimeInterval(secondsLeft)); isRunning = true
                        }
                    }.buttonStyle(.borderedProminent).tint(AppTheme.violet)
                    Button("Сбросить") { secondsLeft = selectedMinutes * 60; isRunning = false; deadline = nil }.buttonStyle(.bordered)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, isRunning, let deadline {
                secondsLeft = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                if secondsLeft == 0 { isRunning = false }
            }
        }
        .task(id: isRunning) {
            guard isRunning else { return }
            while !Task.isCancelled && secondsLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled && isRunning else { return }
                if let deadline { secondsLeft = max(0, Int(ceil(deadline.timeIntervalSinceNow))) }
            }
            if secondsLeft == 0 { isRunning = false }
        }
    }

    private var clockText: String { String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60) }
    private func select(_ minutes: Int) { selectedMinutes = minutes; secondsLeft = minutes * 60; isRunning = false; deadline = nil }
}
