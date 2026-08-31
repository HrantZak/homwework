import SwiftUI

enum AppTheme {
    static let violet = Color(red: 0.43, green: 0.31, blue: 0.95)
    static let coral = Color(red: 1.0, green: 0.46, blue: 0.36)
    static let mint = Color(red: 0.22, green: 0.78, blue: 0.65)
    static let background = Color(uiColor: .systemGroupedBackground)
}

struct SoftCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}
