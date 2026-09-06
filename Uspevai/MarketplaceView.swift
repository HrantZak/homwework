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
    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let byKind = Dictionary(grouping: all, by: \.kind)
    static func product(id: String) -> MarketProduct? { byID[id] }
    static func fontFamily(for product: MarketProduct) -> String {
        product.id == cubeFontID ? "Monocraft" : fontFamilies[abs(product.variant) % fontFamilies.count]
    }
}

struct MarketplaceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kind: MarketProductKind = .ring
    @State private var showAdmin = false
    @State private var selectedProduct: MarketProduct?
    @State private var query = ""
    @State private var collection = false
    @State private var affordableOnly = false
    @State private var descending = false
    @Namespace private var categoryAnimation

    private var ownedIDs: Set<String> { store.ownedMarketIDs }
    private var products: [MarketProduct] {
        let owned = ownedIDs
        let balance = store.coinBalance
        return (MarketCatalog.byKind[kind] ?? []).filter {
            (!collection || owned.contains($0.id)) &&
            (!affordableOnly || owned.contains($0.id) || $0.price <= balance) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }.sorted { descending ? $0.price > $1.price : $0.price < $1.price }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 22) {
                    walletHero.revealOnAppear()
                    Picker("Раздел", selection: $collection) {
                        Text("Каталог").tag(false)
                        Text("Моя коллекция").tag(true)
                    }.pickerStyle(.segmented)
                    categories
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.name).font(.title2.bold())
                            Text("\(products.count) предметов").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Toggle("Хватает монет", isOn: $affordableOnly)
                            Toggle("Сначала дорогие", isOn: $descending)
                        } label: {
                            Label("Фильтры", systemImage: "slider.horizontal.3").font(.caption.bold())
                                .padding(12).background(AppTheme.violet.opacity(0.09), in: Capsule())
                        }
                    }
                    if affordableOnly { StatusPill(title: "Хватает монет", symbol: "checkmark.seal.fill", color: AppTheme.mint) }
                    if products.isEmpty {
                        ContentUnavailableView("Здесь пока пусто", systemImage: collection ? "bag" : "magnifyingglass", description: Text(collection ? "Найди свой первый предмет в каталоге или измени фильтры." : "Измени запрос или выключи фильтр по балансу."))
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                        ForEach(products) { product in productCard(product) }
                    }
                    Label("Монеты за учёбу · покупки без реальных денег", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
                }.padding()
            }.background { AnimatedAppBackground() }.navigationTitle("Маркет")
                .searchable(text: $query, prompt: "Найти свой стиль")
                .toolbar {
                    Menu {
                        Button { showAdmin = true } label: { Label("Администратор", systemImage: "key") }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Настройки маркета")
                }
                .sheet(isPresented: $showAdmin) { AdminCoinView() }
                .sheet(item: $selectedProduct) { product in MarketProductDetailView(product: product) }
                .sensoryFeedback(.selection, trigger: kind)
                .sensoryFeedback(.success, trigger: store.purchasedMarketIDs.count)
        }
    }

    private var categories: some View {
        HStack(spacing: 8) {
            ForEach(MarketProductKind.allCases, id: \.self) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) { kind = item }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: item.symbol).font(.title3)
                        Text(item.name).font(.caption.bold())
                    }.frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(kind == item ? Color.white : Color.secondary)
                        .background {
                            if kind == item { RoundedRectangle(cornerRadius: 20).fill(AppTheme.actionGradient).matchedGeometryEffect(id: "category", in: categoryAnimation) }
                            else { RoundedRectangle(cornerRadius: 20).fill(Color.primary.opacity(0.04)) }
                        }
                }.buttonStyle(ScalePressStyle()).accessibilityAddTraits(kind == item ? .isSelected : [])
            }
        }
    }

    private var walletHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("ТВОЙ СТИЛЬ. ТВОИ ПРАВИЛА.").font(.caption2.bold()).tracking(1.6)
                Spacer()
                Image(systemName: "sparkles").foregroundStyle(AppTheme.gold)
            }.foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle().fill(AppTheme.gold.opacity(0.14)).frame(width: 68, height: 68)
                    Image(systemName: "seal.fill").font(.system(size: 38)).foregroundStyle(AppTheme.gold.gradient)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.coinBalance)").font(.system(size: 42, weight: .bold, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                    Text("монет на новые открытия").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            Divider().overlay(.white.opacity(0.15))
            HStack {
                Label("\(ownedIDs.count) в коллекции", systemImage: "square.stack.3d.up.fill")
                Spacer()
                Text("+12 за задание")
            }.font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
        }.foregroundStyle(.white).padding(24).background { OrbitBackdrop() }
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .animation(reduceMotion ? nil : .snappy, value: store.coinBalance)
    }

    private func productCard(_ product: MarketProduct) -> some View {
        let owned = ownedIDs.contains(product.id)
        let selected = equipped(product)
        let tint = Color(hue: Double(product.variant % 25) / 25, saturation: 0.65, brightness: 0.85)
        return Button { selectedProduct = product } label: {
            VStack(alignment: .leading, spacing: 13) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [tint.opacity(0.16), tint.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    MarketArtwork(product: product).frame(maxWidth: .infinity, maxHeight: .infinity)
                    if owned { Image(systemName: selected ? "checkmark.seal.fill" : "checkmark.circle.fill").foregroundStyle(AppTheme.mint).padding(9) }
                }.frame(height: 116)
                Text(product.name).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(2).frame(minHeight: 38, alignment: .top)
                Text(product.kind == .ring ? "Рамка профиля" : product.kind == .font ? "Твой почерк" : "Подпись под именем").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Label(selected ? "Выбрано" : owned ? "В коллекции" : "\(product.price)", systemImage: selected ? "checkmark" : owned ? "bag.fill" : "seal.fill")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption2)
                }.font(.caption.bold()).foregroundStyle(selected ? AppTheme.mint : AppTheme.violet)
                    .padding(11).background((selected ? AppTheme.mint : AppTheme.violet).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }.padding(12).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 25))
                .overlay { RoundedRectangle(cornerRadius: 25).stroke(selected ? AppTheme.mint.opacity(0.65) : tint.opacity(0.14), lineWidth: 1) }
        }.buttonStyle(ScalePressStyle())
    }
    private func equipped(_ product: MarketProduct) -> Bool { switch product.kind { case .ring: store.equippedRingID == product.id; case .font: store.equippedFontID == product.id; case .title: store.equippedTitleID == product.id } }
}

private struct MarketArtwork: View {
    let product: MarketProduct
    var body: some View {
        switch product.kind {
        case .ring:
            AvatarRingView(ringID: product.id, size: 66, animated: false) {
                Image(systemName: "person.fill").font(.title2).foregroundStyle(.white).frame(width: 48, height: 48).background(AppTheme.deepViolet, in: Circle())
            }
        case .font:
            VStack(spacing: 5) {
                Text("Aa Бб").font(.custom(MarketCatalog.fontFamily(for: product), size: 30))
                Text("Твой ритм").font(.custom(MarketCatalog.fontFamily(for: product), size: 13))
            }.foregroundStyle(AppTheme.violet)
        case .title:
            VStack(spacing: 8) {
                Image(systemName: "crown.fill").font(.largeTitle).foregroundStyle(AppTheme.gold.gradient)
                Text(product.name).font(.system(size: 10, weight: .bold)).lineLimit(1).padding(8).foregroundStyle(.white).background(AppTheme.actionGradient, in: Capsule())
            }.padding(8)
        }
    }
}

struct AvatarRingView<Content: View>: View {
    let ringID: String
    let size: CGFloat
    let animated: Bool
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var rotates = false
    @State private var visible = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    init(ringID: String, size: CGFloat, animated: Bool = true, @ViewBuilder content: () -> Content) {
        self.ringID = ringID; self.size = size; self.animated = animated; self.content = content()
    }
    private var variant: Int { max(0, Int(ringID.split(separator: "-").last ?? "0") ?? 0) }
    private var motionEnabled: Bool { animated && visible && !reduceMotion && !lowPower && scenePhase == .active }
    private var colors: [Color] { [Color(hue: Double(variant % 20) / 20, saturation: 0.8, brightness: 0.95), AppTheme.cyan, .white, AppTheme.violet] }

    var body: some View {
        ZStack {
            Circle().stroke(colors[0].opacity(0.12), lineWidth: size * 0.13)
            Circle().stroke(AngularGradient(colors: colors, center: .center), style: StrokeStyle(lineWidth: max(3, size * 0.055), lineCap: .round, dash: variant % 3 == 0 ? [] : [size * 0.18, size * 0.055]))
                .rotationEffect(.degrees(rotates ? 360 : 0))
            Circle().stroke(.white.opacity(0.22), lineWidth: 1).padding(size * 0.075)
            content
        }.frame(width: size, height: size)
            .onAppear { visible = true }
            .onDisappear { visible = false }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
            .task(id: motionEnabled) {
                var transaction = Transaction(); transaction.disablesAnimations = true
                withTransaction(transaction) { rotates = false }
                guard motionEnabled else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: Double(10 + variant % 5)).repeatForever(autoreverses: false)) { rotates = true }
            }
    }
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
                    purchaseSummary
                }.padding(20)
            }
            .background { AnimatedAppBackground() }
            .safeAreaInset(edge: .bottom) { actionButton.padding(.horizontal, 20).padding(.vertical, 12).background(Color(uiColor: .systemBackground)) }
            .sensoryFeedback(.success, trigger: isEquipped)
            .navigationTitle("Примерить стиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
            .task(id: product.id) { await startPreview() }
        }
    }

    @ViewBuilder private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground))
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
        let owned = store.ownedMarketIDs.contains(product.id)
        let equipped = isEquipped
        let missing = max(0, product.price - store.coinBalance)
        return Button { buyOrEquip() } label: {
            Label(equipped ? "Уже выбрано" : owned ? "Применить стиль" : missing > 0 ? "Не хватает \(missing) монет" : "Купить за \(product.price) монет", systemImage: equipped ? "checkmark.seal.fill" : owned ? "tshirt.fill" : "seal.fill")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16).foregroundStyle(.white).background(equipped ? AppTheme.mint : AppTheme.violet, in: RoundedRectangle(cornerRadius: 18))
        }.disabled(equipped || (!owned && missing > 0)).opacity(!owned && missing > 0 ? 0.55 : 1).buttonStyle(ScalePressStyle())
    }

    private var purchaseSummary: some View {
        SoftCard {
            VStack(spacing: 14) {
                HStack { Text("Твой баланс").foregroundStyle(.secondary); Spacer(); Label("\(store.coinBalance)", systemImage: "seal.fill").bold().foregroundStyle(AppTheme.gold) }
                if !store.ownedMarketIDs.contains(product.id) {
                    HStack { Text("Стоимость").foregroundStyle(.secondary); Spacer(); Text("\(product.price)").bold() }
                    Divider()
                    if store.coinBalance >= product.price {
                        HStack { Text("После покупки"); Spacer(); Text("\(store.coinBalance - product.price) монет").bold().foregroundStyle(AppTheme.mint) }
                    } else {
                        Label("Выполняй задания и добавляй оценки, чтобы накопить монеты.", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Покупка сразу применит этот стиль. Другие купленные предметы останутся в коллекции.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Label("Уже в твоей коллекции · повторно платить не нужно", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(AppTheme.mint)
                    if isEquipped { Button("Вернуть стандартный стиль") { resetStyle() }.font(.subheadline.bold()) }
                }
            }
        }
    }

    private func resetStyle() {
        switch product.kind {
        case .ring: store.equippedRingID = ""
        case .font: store.equippedFontID = ""
        case .title: store.equippedTitleID = ""
        }
        message = "Стандартный стиль восстановлен"
    }

    private var isEquipped: Bool { switch product.kind { case .ring: store.equippedRingID == product.id; case .font: store.equippedFontID == product.id; case .title: store.equippedTitleID == product.id } }
    private var detailText: String { switch product.kind { case .font: "Посмотри, как шрифт пишет фразу, а затем примени его ко всему интерфейсу."; case .ring: "Рамка плавно движется вокруг аватара и будет видна в профиле."; case .title: "Редкий знак статуса под именем — его увидят друзья и другие ученики." } }
    private var titleGradient: LinearGradient { LinearGradient(colors: [Color(hue: Double(product.variant % 25) / 25, saturation: 0.75, brightness: 0.82), AppTheme.violet], startPoint: .leading, endPoint: .trailing) }
    private func buyOrEquip() { if store.ownedMarketIDs.contains(product.id) { store.equip(product); message = "Выбрано: \(product.name)" } else if store.buy(product) { message = "Покупка готова и сразу выбрана" } else { message = "Недостаточно монет" } }
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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { titleGlow = true }
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
