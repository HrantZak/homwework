import CryptoKit
import SwiftUI

enum MarketProductKind: String, CaseIterable, Hashable, Sendable { case ring, font, title
    var name: String { switch self { case .ring: "Рамки"; case .font: "Шрифты"; case .title: "Титулы" } }
    var symbol: String { switch self { case .ring: "circle.hexagongrid.fill"; case .font: "textformat"; case .title: "crown.fill" } }
}

struct MarketProduct: Identifiable, Hashable, Sendable {
    let id: String; let kind: MarketProductKind; let name: String; let detail: String; let price: Int; let variant: Int
}

enum MarketCatalog {
    static let cubeFontID = "font-monocraft"
    private static let fontFamilies = ["Avenir Next","American Typewriter","Baskerville","Chalkboard SE","Cochin","Copperplate","Courier New","Didot","Futura","Georgia","Gill Sans","Helvetica Neue","Hoefler Text","Marker Felt","Menlo","Noteworthy","Optima","Palatino","Papyrus","Snell Roundhand","Times New Roman","Trebuchet MS","Verdana","Rockwell","Academy Engraved LET"]
    static let all: [MarketProduct] = {
        let ringNames = ["Орбита","Неон","Аврора","Галактика","Комета","Сапфир","Изумруд","Рубин","Золото","Плазма"]
        let fontNames = ["Мягкий","Академический","Кодер","Классика","Космос","Конспект","Фокус","Премиум","Лаборатория","Моно"]
        let titleNames = ["Первый шаг","Знаток","Отличник","Исследователь","Мастер фокуса","Повелитель задач","Легенда класса","Архитектор знаний","Чемпион","Недосягаемый"]
        var products: [MarketProduct] = [
            MarketProduct(id: cubeFontID, kind: .font, name: "Кубический мир", detail: "Пиксельный шрифт Monocraft в стиле Minecraft", price: 550, variant: 100)
        ]
        for index in 0..<50 {
            products.append(MarketProduct(id: "ring-\(index)", kind: .ring, name: "\(ringNames[index % ringNames.count]) \(index / 10 + 1)", detail: "Анимированная рамка аватара", price: 80 + index * 22, variant: index))
            products.append(MarketProduct(id: "font-\(index)", kind: .font, name: "\(fontNames[index % fontNames.count]) \(index / 10 + 1)", detail: "Стиль текста всего приложения", price: 120 + index * 25, variant: index))
            products.append(MarketProduct(id: "title-\(index)", kind: .title, name: "\(titleNames[index % titleNames.count]) \(index / 10 + 1)", detail: "Титул, который увидят друзья", price: 60 + index * 18, variant: index))
        }
        return products
    }()
    static func product(id: String) -> MarketProduct? { all.first { $0.id == id } }
    static func fontFamily(for product: MarketProduct) -> String {
        product.id == cubeFontID ? "Monocraft" : fontFamilies[abs(product.variant) % fontFamilies.count]
    }
}

struct MarketplaceView: View {
    @EnvironmentObject private var store: AppStore
    @State private var kind: MarketProductKind = .ring
    @State private var showAdmin = false
    @State private var selectedProduct: MarketProduct?
    private var products: [MarketProduct] { MarketCatalog.all.filter { $0.kind == kind } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    walletHero
                    Picker("Категория", selection: $kind) { ForEach(MarketProductKind.allCases, id: \.self) { Label($0.name, systemImage: $0.symbol).tag($0) } }.pickerStyle(.segmented)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { ForEach(products) { product in productCard(product) } }
                }.padding()
            }.background { AnimatedAppBackground() }.navigationTitle("Маркетплейс")
                .toolbar { Button { showAdmin = true } label: { Image(systemName: "key.fill") }.accessibilityLabel("Панель администратора") }
                .sheet(isPresented: $showAdmin) { AdminCoinView() }
                .sheet(item: $selectedProduct) { product in MarketProductDetailView(product: product) }
                .sensoryFeedback(.success, trigger: store.purchasedMarketIDs.count)
        }
    }

    private var walletHero: some View {
        ZStack { LinearGradient(colors: [AppTheme.deepViolet, AppTheme.violet, AppTheme.gold], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.12)).frame(width: 170).offset(x: 125, y: -45)
            VStack(alignment: .leading, spacing: 13) { Text("БАЛАНС").font(.caption.bold()).tracking(1.5).opacity(0.72); HStack { Label("\(store.coinBalance)", systemImage: "seal.fill").font(.system(size: 34, weight: .heavy, design: .rounded)); Spacer(); Text("монет").font(.headline).opacity(0.8) }; Text("+12 за выполненное задание · +6 за оценку · ещё +4 за 9–10").font(.caption).opacity(0.78) }.foregroundStyle(.white).padding(22)
        }.frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 30)).shadow(color: AppTheme.violet.opacity(0.28), radius: 20, y: 10)
    }

    private func productCard(_ product: MarketProduct) -> some View {
        let owned = store.purchasedMarketIDs.contains(product.id)
        let equipped = equipped(product)
        return Button { selectedProduct = product } label: {
            VStack(alignment: .leading, spacing: 10) {
                productPreview(product).frame(maxWidth: .infinity).frame(height: 72)
                Text(product.name).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                Text(product.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2).frame(height: 30, alignment: .top)
                HStack { Label(equipped ? "Выбрано" : owned ? "Надеть" : "\(product.price)", systemImage: equipped ? "checkmark.circle.fill" : owned ? "tshirt.fill" : "seal.fill"); Spacer() }.font(.caption.bold()).foregroundStyle(equipped ? AppTheme.mint : AppTheme.violet)
            }.padding(14).frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22)).overlay { RoundedRectangle(cornerRadius: 22).stroke(equipped ? AppTheme.mint.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: equipped ? 2 : 1) }
        }.buttonStyle(ScalePressStyle())
    }

    @ViewBuilder private func productPreview(_ product: MarketProduct) -> some View {
        switch product.kind {
        case .ring: AvatarRingView(ringID: product.id, size: 62, animated: false) { Image(systemName: "person.fill").foregroundStyle(.white).frame(width: 42, height: 42).background(AppTheme.deepViolet, in: Circle()) }
        case .font:
            VStack(spacing: 2) {
                Text(product.id == MarketCatalog.cubeFontID ? "КУБ" : "Aa")
                    .font(.custom(MarketCatalog.fontFamily(for: product), size: product.id == MarketCatalog.cubeFontID ? 25 : 34))
                if product.id == MarketCatalog.cubeFontID { Text("PIXEL").font(.custom("Monocraft", size: 10)) }
            }
            .foregroundStyle(product.id == MarketCatalog.cubeFontID ? AppTheme.mint : Color(hue: Double(product.variant % 20) / 20, saturation: 0.7, brightness: 0.82))
        case .title: Label(product.name, systemImage: "crown.fill").font(.caption2.bold()).padding(.horizontal, 10).frame(height: 32).foregroundStyle(.white).background(titleGradient(product), in: Capsule())
        }
    }
    private func equipped(_ product: MarketProduct) -> Bool { switch product.kind { case .ring: store.equippedRingID == product.id; case .font: store.equippedFontID == product.id; case .title: store.equippedTitleID == product.id } }
    private func titleGradient(_ product: MarketProduct) -> LinearGradient { LinearGradient(colors: [Color(hue: Double(product.variant % 25) / 25, saturation: 0.75, brightness: 0.8), AppTheme.violet], startPoint: .leading, endPoint: .trailing) }
}

struct AvatarRingView<Content: View>: View {
    let ringID: String; let size: CGFloat; let animated: Bool; let content: Content
    @State private var rotates = false
    init(ringID: String, size: CGFloat, animated: Bool = true, @ViewBuilder content: () -> Content) { self.ringID = ringID; self.size = size; self.animated = animated; self.content = content() }
    private var variant: Int { Int(ringID.split(separator: "-").last ?? "0") ?? 0 }
    var body: some View { ZStack { Circle().stroke(AngularGradient(colors: colors + [colors[0]], center: .center), lineWidth: max(3, size * 0.08)).rotationEffect(.degrees(rotates ? 360 : 0)); content }.frame(width: size, height: size).onAppear { guard animated else { return }; withAnimation(.linear(duration: Double(4 + variant % 5)).repeatForever(autoreverses: false)) { rotates = true } } }
    private var colors: [Color] { [Color(hue: Double(variant % 20) / 20, saturation: 0.85, brightness: 0.95), Color(hue: Double((variant * 7 + 5) % 20) / 20, saturation: 0.8, brightness: 0.95), .white] }
}

private struct MarketProductDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let product: MarketProduct
    @State private var typedText = ""
    @State private var titleGlow = false
    @State private var message = ""
    private let sample = "Учись. Создавай. Побеждай!"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview
                    VStack(alignment: .leading, spacing: 8) {
                        Label(product.kind.name, systemImage: product.kind.symbol).font(.caption.bold()).foregroundStyle(AppTheme.violet)
                        Text(product.name).font(.largeTitle.bold())
                        Text(detailText).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if !message.isEmpty {
                        Label(message, systemImage: message == "Недостаточно монет" ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .font(.subheadline.bold()).foregroundStyle(message == "Недостаточно монет" ? .orange : AppTheme.mint)
                    }
                    actionButton
                }.padding(20)
            }
            .background { AnimatedAppBackground() }
            .navigationTitle("Предпросмотр")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
            .task(id: product.id) { await startPreview() }
        }
    }

    @ViewBuilder private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.regularMaterial)
            switch product.kind {
            case .font:
                VStack(spacing: 18) {
                    Text("Aa Бб 123").font(.custom(MarketCatalog.fontFamily(for: product), size: 28)).foregroundStyle(AppTheme.violet)
                    Text(typedText + (typedText.count < sample.count ? "▌" : ""))
                        .font(.custom(MarketCatalog.fontFamily(for: product), size: 25)).multilineTextAlignment(.center).frame(minHeight: 70)
                    Text("Так будет выглядеть текст во всём приложении").font(.caption).foregroundStyle(.secondary)
                }.padding()
            case .ring:
                VStack(spacing: 20) {
                    AvatarRingView(ringID: product.id, size: 150, animated: !reduceMotion) {
                        Image(systemName: "person.fill").font(.system(size: 54)).foregroundStyle(.white).frame(width: 116, height: 116).background(AppTheme.deepViolet.gradient, in: Circle())
                    }
                    Text("Живой предпросмотр рамки").font(.headline)
                }
            case .title:
                VStack(spacing: 18) {
                    Image(systemName: "crown.fill").font(.system(size: 48)).foregroundStyle(AppTheme.gold).scaleEffect(titleGlow ? 1.08 : 0.92)
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(AppTheme.violet)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.studentName).font(.headline)
                            Label(product.name, systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 11).padding(.vertical, 7).background(titleGradient, in: Capsule())
                        }
                    }.padding(18).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    Text("Так титул увидят друзья в твоём профиле").font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
        }.frame(minHeight: 300).shadow(color: AppTheme.violet.opacity(0.12), radius: 16, y: 8)
    }

    private var actionButton: some View {
        let owned = store.purchasedMarketIDs.contains(product.id)
        let equipped = isEquipped
        return Button { buyOrEquip() } label: {
            Label(equipped ? "Уже выбрано" : owned ? "Выбрать" : "Купить за \(product.price) монет", systemImage: equipped ? "checkmark.seal.fill" : owned ? "tshirt.fill" : "seal.fill")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16).foregroundStyle(.white).background(equipped ? AppTheme.mint : AppTheme.violet, in: RoundedRectangle(cornerRadius: 18))
        }.disabled(equipped).buttonStyle(ScalePressStyle())
    }

    private var isEquipped: Bool { switch product.kind { case .ring: store.equippedRingID == product.id; case .font: store.equippedFontID == product.id; case .title: store.equippedTitleID == product.id } }
    private var detailText: String { switch product.kind { case .font: "Посмотри, как шрифт пишет фразу, а затем примени его ко всему интерфейсу."; case .ring: "Рамка плавно движется вокруг аватара и будет видна в профиле."; case .title: "Редкий знак статуса под именем — его увидят друзья и другие ученики." } }
    private var titleGradient: LinearGradient { LinearGradient(colors: [Color(hue: Double(product.variant % 25) / 25, saturation: 0.75, brightness: 0.82), AppTheme.violet], startPoint: .leading, endPoint: .trailing) }
    private func buyOrEquip() { if store.purchasedMarketIDs.contains(product.id) { store.equip(product); message = "Выбрано: \(product.name)" } else if store.buy(product) { message = "Покупка готова и сразу выбрана" } else { message = "Недостаточно монет" } }
    private func startPreview() async {
        if product.kind == .font {
            typedText = ""
            if reduceMotion { typedText = sample; return }
            for character in sample {
                guard !Task.isCancelled else { return }
                typedText.append(character)
                try? await Task.sleep(for: .milliseconds(58))
            }
        } else if product.kind == .title, !reduceMotion {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { titleGlow = true }
        }
    }
}

private struct AdminCoinView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""; @State private var amount = 500; @State private var error = ""
    var body: some View { NavigationStack { Form { Section("Доступ") { SecureField("Пароль администратора", text: $password) }; Section("Монеты") { Stepper("Выдать: \(amount)", value: $amount, in: 100...10000, step: 100) }; if !error.isEmpty { Text(error).foregroundStyle(.red) } }.navigationTitle("Администратор").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Выдать") { grant() } } } } }
    private func grant() { let digest = SHA256.hash(data: Data(password.utf8)).map { String(format: "%02x", $0) }.joined(); guard digest == "3d04aad931d69b96c01ef6b5859d25936a49778fbba5ffaca574ead2091b024f" else { error = "Неверный пароль"; return }; store.adminCoins += amount; dismiss() }
}
