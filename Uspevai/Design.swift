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
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 25, style: .continuous).fill(LinearGradient(colors: [.white.opacity(0.07), AppTheme.violet.opacity(0.018), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)).allowsHitTesting(false) }
            .overlay { RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(.primary.opacity(0.055), lineWidth: 1) }
            .shadow(color: .black.opacity(0.028), radius: 5, y: 2)
    }
}

struct AnimatedAppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background
            LinearGradient(colors: [AppTheme.violet.opacity(0.07), .clear, AppTheme.mint.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }.ignoresSafeArea()
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
