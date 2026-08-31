import SwiftUI

enum AppTheme {
    static let violet = Color(red: 0.43, green: 0.31, blue: 0.95)
    static let coral = Color(red: 1.0, green: 0.46, blue: 0.36)
    static let mint = Color(red: 0.22, green: 0.78, blue: 0.65)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let blue = Color(red: 0.15, green: 0.48, blue: 1.0)
}

struct SoftCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(LinearGradient(colors: [.white.opacity(0.65), AppTheme.violet.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1) }
            .shadow(color: AppTheme.violet.opacity(0.08), radius: 22, y: 10)
    }
}

struct AnimatedAppBackground: View {
    @State private var moving = false
    var body: some View {
        ZStack {
            AppTheme.background
            Circle().fill(AppTheme.violet.opacity(0.13)).blur(radius: 50).frame(width: 260).offset(x: moving ? 150 : -150, y: moving ? -300 : -180)
            Circle().fill(AppTheme.mint.opacity(0.10)).blur(radius: 55).frame(width: 240).offset(x: moving ? -130 : 140, y: moving ? 330 : 220)
        }.ignoresSafeArea().onAppear { withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { moving.toggle() } }
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
    func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.94 : 1).opacity(configuration.isPressed ? 0.82 : 1).animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed) }
}
