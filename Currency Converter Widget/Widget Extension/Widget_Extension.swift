
import WidgetKit
import SwiftUI
import AppIntents

// --- 1. MODEL WYDATKU (Musi być identyczny jak w aplikacji) ---
struct ExpenseItem: Codable, Identifiable {
    var id = UUID()
    let amount: Double
    let currency: String
    let convertedAmount: Double
    let targetCurrency: String
    let date: Date
    var note: String? // Pole opcjonalne, zgodne z aplikacją
}

// --- 2. STORAGE ---
struct WidgetStorage {
    // UWAGA: Upewnij się, że App Group jest włączone w obu targetach
    static let suiteName = "group.com.currencyconverter.shared"
    static var shared: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }
    
    static let amountKey = "widgetAmount"
    static let rateKey = "widgetRate"
    static let lastFetchKey = "widgetLastFetchDate"
    static let fromKey = "widgetFromCurrency"
    static let toKey = "widgetToCurrency"
    static let expensesKey = "savedExpensesList"
    static let lastSaveKey = "widgetLastSaveDate"
    
    static var amount: Double {
        get { return shared.double(forKey: amountKey) }
        set { shared.set(newValue, forKey: amountKey) }
    }
    
    static var rate: Double {
        get { return shared.double(forKey: rateKey) }
        set { shared.set(newValue, forKey: rateKey) }
    }
    
    static var lastFetchDate: Date? {
        get { return shared.object(forKey: lastFetchKey) as? Date }
        set { shared.set(newValue, forKey: lastFetchKey) }
    }
    
    static var lastSaveDate: Date? {
        get { return shared.object(forKey: lastSaveKey) as? Date }
        set { shared.set(newValue, forKey: lastSaveKey) }
    }
    
    static var activeFrom: String? {
        get { return shared.string(forKey: fromKey) }
        set { shared.set(newValue, forKey: fromKey) }
    }
    
    static var activeTo: String? {
        get { return shared.string(forKey: toKey) }
        set { shared.set(newValue, forKey: toKey) }
    }
    
    static func saveExpense(amount: Double, from: String, to: String, rate: Double) {
        guard amount > 0 else { return }
        
        let newItem = ExpenseItem(
            amount: amount,
            currency: from,
            convertedAmount: amount * rate,
            targetCurrency: to,
            date: Date(),
            note: nil
        )
        
        var currentExpenses = getExpenses()
        currentExpenses.append(newItem)
        
        if let encoded = try? JSONEncoder().encode(currentExpenses) {
            shared.set(encoded, forKey: expensesKey)
        }
        
        // Zapisz czas zapisu, aby wyświetlić komunikat sukcesu
        lastSaveDate = Date()
    }
    
    static func getExpenses() -> [ExpenseItem] {
        if let data = shared.data(forKey: expensesKey),
           let items = try? JSONDecoder().decode([ExpenseItem].self, from: data) {
            return items
        }
        return []
    }
}

// --- 3. PROVIDER ---

struct SimpleEntry: TimelineEntry {
    let date: Date
    let rate: Double
    let amount: Double
    let from: String
    let to: String
    let showSuccess: Bool
}

@available(iOS 17.0, *)
struct Provider: AppIntentTimelineProvider {
    typealias Entry = SimpleEntry
    typealias Intent = CurrencySelectionIntent

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), rate: 4.0, amount: 100, from: "USD", to: "PLN", showSuccess: false)
    }

    func snapshot(for configuration: CurrencySelectionIntent, in context: Context) async -> SimpleEntry {
        return await prepareEntry(configuration: configuration)
    }
    
    func timeline(for configuration: CurrencySelectionIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = await prepareEntry(configuration: configuration)
        
        // Jeśli wyświetlamy sukces, odśwież za 2 sekundy, aby go ukryć
        if entry.showSuccess {
            let nextUpdate = Calendar.current.date(byAdding: .second, value: 2, to: .now)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } else {
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
    }
    
    private func prepareEntry(configuration: CurrencySelectionIntent) async -> SimpleEntry {
        let configFrom = configuration.fromCurrency?.id ?? "USD"
        let configTo = configuration.toCurrency?.id ?? "PLN"
        
        var finalFrom = WidgetStorage.activeFrom ?? configFrom
        var finalTo = WidgetStorage.activeTo ?? configTo
        
        if WidgetStorage.activeFrom == nil {
            WidgetStorage.activeFrom = configFrom
            WidgetStorage.activeTo = configTo
            finalFrom = configFrom
            finalTo = configTo
        }
        
        let currentRate = await getRateSmart(from: finalFrom, to: finalTo)
        let showSuccess = shouldShowSuccess()
        
        return SimpleEntry(
            date: Date(),
            rate: currentRate,
            amount: WidgetStorage.amount,
            from: finalFrom,
            to: finalTo,
            showSuccess: showSuccess
        )
    }
    
    private func shouldShowSuccess() -> Bool {
        guard let lastSave = WidgetStorage.lastSaveDate else { return false }
        return Date().timeIntervalSince(lastSave) < 3.0
    }
    
    private func getRateSmart(from: String, to: String) async -> Double {
        if from == to { return 1.0 }
        
        let isSamePair = (WidgetStorage.activeFrom == from && WidgetStorage.activeTo == to)
        let hasRate = WidgetStorage.rate > 0
        let lastUpdate = WidgetStorage.lastFetchDate ?? Date.distantPast
        let isFresh = Date().timeIntervalSince(lastUpdate) < 3600
        
        if isSamePair && hasRate && isFresh {
            return WidgetStorage.rate
        }
        
        let urlString = "https://api.frankfurter.app/latest?from=\(from)&to=\(to)"
        guard let url = URL(string: urlString) else { return WidgetStorage.rate }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            let newRate = response.rates[to] ?? 0.0
            
            if newRate > 0 {
                WidgetStorage.rate = newRate
                WidgetStorage.lastFetchDate = Date()
                WidgetStorage.activeFrom = from
                WidgetStorage.activeTo = to
                return newRate
            }
        } catch {
            print("Błąd sieci")
        }
        return WidgetStorage.rate
    }
}

struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
}

// --- 4. VIEWS ---

struct WidgetExtensionEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            // Tło
            switch family {
            case .accessoryRectangular, .accessoryCircular, .accessoryInline:
                EmptyView()
            default:
                LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            // Zawartość
            switch family {
            case .systemSmall: SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            case .systemLarge: LargeWidgetView(entry: entry)
            case .accessoryCircular: AccessoryCircularView(entry: entry)
            case .accessoryRectangular: AccessoryRectangularView(entry: entry)
            case .accessoryInline: AccessoryInlineView(entry: entry)
            default: SmallWidgetView(entry: entry)
            }
            
            // OVERLAY SUKCESU
            if entry.showSuccess {
                SuccessOverlay()
            }
        }
    }
}

struct SuccessOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                Text("Zapisano!")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity.animation(.easeInOut))
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(entry.from).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                
                Button(intent: SwapCurrenciesIntent()) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }.buttonStyle(.plain)
                
                Text(entry.to).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 4)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 0) {
                Text(formatAmount(entry.amount))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                
                let result = entry.amount * entry.rate
                Text(formatAmount(result))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            
            KeypadView(buttonHeight: 20, fontSize: 12, spacing: 2, showSaveButton: false)
        }
        .widgetURL(URL(string: "currencyconverter://open"))
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.from).font(.caption.weight(.bold)).foregroundStyle(.blue)
                    Button(intent: SwapCurrenciesIntent()) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.3))
                    }.buttonStyle(.plain)
                    Text(entry.to).font(.caption.weight(.bold)).foregroundStyle(.purple)
                }
                Spacer()
                Text(formatAmount(entry.amount))
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundStyle(.secondary)
                let result = entry.amount * entry.rate
                Text(formatAmount(result))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer()
                Text("1 \(entry.from) ≈ \(String(format: "%.3f", entry.rate)) \(entry.to)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            KeypadView(buttonHeight: 30, fontSize: 16, spacing: 5, showSaveButton: true)
                .frame(width: 130)
        }
        .padding()
        .widgetURL(URL(string: "currencyconverter://open"))
    }
}

struct LargeWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                ZStack {
                    HStack {
                        Label(entry.from, systemImage: "arrow.up.circle.fill")
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Label(entry.to, systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(.green.opacity(0.8))
                    }
                    Button(intent: SwapCurrenciesIntent()) {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .font(.caption.weight(.bold))
                
                Divider().background(.white.opacity(0.2))
                Spacer(minLength: 0)
                
                Text(formatAmount(entry.amount))
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                
                let result = entry.amount * entry.rate
                Text(formatAmount(result))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Text("Kurs: \(String(format: "%.4f", entry.rate))")
                        .font(.caption2)
                        .padding(4)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxHeight: .infinity)
            
            KeypadView(buttonHeight: 45, fontSize: 24, spacing: 8, showSaveButton: true)
                .padding(.bottom, 4)
        }
        .padding(16)
        .widgetURL(URL(string: "currencyconverter://open"))
    }
}

// --- REST OF VIEWS ---

struct AccessoryRectangularView: View {
    var entry: Provider.Entry
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(entry.from).font(.headline)
                Image(systemName: "arrow.right").font(.caption)
                Text(entry.to).font(.headline)
            }
            let result = entry.amount * entry.rate
            Text("\(formatAmount(entry.amount)) = \(formatAmount(result))")
                .minimumScaleFactor(0.5)
        }
    }
}

struct AccessoryCircularView: View {
    var entry: Provider.Entry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.to).font(.caption2.bold())
                Text(String(format: "%.2f", entry.rate)).font(.system(size: 10))
            }
        }
    }
}

struct AccessoryInlineView: View {
    var entry: Provider.Entry
    var body: some View {
        Text("1 \(entry.from) = \(String(format: "%.2f", entry.rate)) \(entry.to)")
    }
}

struct KeypadView: View {
    var buttonHeight: CGFloat
    var fontSize: CGFloat
    var spacing: CGFloat
    var showSaveButton: Bool
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(1...9, id: \.self) { num in
                NumberButton(number: num, height: buttonHeight, fontSize: fontSize)
            }
            
            Button(intent: ClearAmountIntent()) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.2))
                    Image(systemName: "trash").font(.system(size: fontSize * 0.7)).foregroundStyle(Color.red.opacity(0.8))
                }
                .frame(height: buttonHeight)
            }
            .buttonStyle(.plain)
            
            NumberButton(number: 0, height: buttonHeight, fontSize: fontSize)
            
            if showSaveButton {
                Button(intent: SaveExpenseIntent()) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.green)
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: fontSize * 0.6, weight: .bold))
                            Text("Zapisz")
                                .font(.system(size: fontSize * 0.4, weight: .bold))
                        }
                        .foregroundStyle(Color.black.opacity(0.7))
                    }
                    .frame(height: buttonHeight)
                }
                .buttonStyle(.plain)
            } else {
                Button(intent: RefreshIntent()) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.2))
                        Image(systemName: "arrow.clockwise").font(.system(size: fontSize * 0.7)).foregroundStyle(Color.blue.opacity(0.8))
                    }
                    .frame(height: buttonHeight)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct NumberButton: View {
    let number: Int
    let height: CGFloat
    let fontSize: CGFloat
    
    var body: some View {
        Button(intent: TypeNumberIntent(number)) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))
                Text("\(number)").font(.system(size: fontSize, weight: .medium, design: .rounded)).foregroundStyle(.white)
            }
            .frame(height: height)
        }
        .buttonStyle(.plain)
    }
}

func formatAmount(_ val: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: val)) ?? "0"
}

func triggerHaptic() {
    // Note: Haptics might not trigger in all widget contexts, but calling it is safe
}

// --- INTENTS ---

struct TypeNumberIntent: AppIntent {
    static var title: LocalizedStringResource = "Wpisz cyfrę"
    @Parameter(title: "Cyfra") var number: Int
    init() {}
    init(_ number: Int) { self.number = number }
    
    func perform() async throws -> some IntentResult {
        let current = WidgetStorage.amount
        if current < 1_000_000_000 {
            let newAmount = (current * 10) + Double(number)
            WidgetStorage.amount = newAmount
        }
        return .result()
    }
}

struct SwapCurrenciesIntent: AppIntent {
    static var title: LocalizedStringResource = "Zamień Waluty"
    func perform() async throws -> some IntentResult {
        let currentFrom = WidgetStorage.activeFrom ?? "USD"
        let currentTo = WidgetStorage.activeTo ?? "PLN"
        let currentRate = WidgetStorage.rate
        
        WidgetStorage.activeFrom = currentTo
        WidgetStorage.activeTo = currentFrom
        if currentRate > 0 { WidgetStorage.rate = 1.0 / currentRate }
        WidgetStorage.lastFetchDate = Date.distantPast
        return .result()
    }
}

struct ClearAmountIntent: AppIntent {
    static var title: LocalizedStringResource = "Wyczyść"
    func perform() async throws -> some IntentResult {
        WidgetStorage.amount = 0
        return .result()
    }
}

struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Odśwież"
    func perform() async throws -> some IntentResult {
        WidgetStorage.lastFetchDate = Date.distantPast
        return .result()
    }
}

struct SaveExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Zapisz Wydatek"
    
    func perform() async throws -> some IntentResult {
        let amount = WidgetStorage.amount
        let from = WidgetStorage.activeFrom ?? "USD"
        let to = WidgetStorage.activeTo ?? "PLN"
        let rate = WidgetStorage.rate
        
        if amount > 0 {
            WidgetStorage.saveExpense(amount: amount, from: from, to: to, rate: rate)
            WidgetStorage.amount = 0 // Clear after save
        }
        return .result()
    }
}

// --- CONFIGURATION ---

struct CurrencyEntity: AppEntity {
    let id: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Waluta"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
    static var defaultQuery = CurrencyQuery()
}

struct CurrencyQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        allCurrencies.map { CurrencyEntity(id: $0) }
    }
    func entities(matching string: String) async throws -> [CurrencyEntity] {
        allCurrencies.filter { $0.localizedCaseInsensitiveContains(string) }.map { CurrencyEntity(id: $0) }
    }
    func suggestedEntities() async throws -> [CurrencyEntity] {
        allCurrencies.map { CurrencyEntity(id: $0) }
    }
}

@available(iOS 17.0, *)
struct CurrencySelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Konfiguracja Walut"
    static var description = IntentDescription("Wybierz waluty do przeliczania.")

    @Parameter(title: "Z Waluty")
    var fromCurrency: CurrencyEntity?

    @Parameter(title: "Na Walutę")
    var toCurrency: CurrencyEntity?
    
    init() {
        self.fromCurrency = CurrencyEntity(id: "THB")
        self.toCurrency = CurrencyEntity(id: "PLN")
    }
}

let allCurrencies = ["PLN", "USD", "EUR", "GBP", "CHF", "JPY", "CZK", "NOK", "SEK", "CAD", "AUD", "THB", "HUF", "DKK"]

@main
struct WidgetExtensionWidget: Widget {
    let kind: String = "Widget_Extension"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CurrencySelectionIntent.self, provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Kalkulator Walut")
        .description("Przeliczaj waluty błyskawicznie.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
