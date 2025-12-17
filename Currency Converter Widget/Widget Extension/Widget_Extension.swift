import WidgetKit
import SwiftUI
import AppIntents

// --- 1. MODEL DANYCH I LISTA WALUT ---

// Lista dostępnych walut
let allCurrencies = [
    "PLN", "USD", "EUR", "GBP", "CHF", "JPY", "CZK", "NOK", "SEK", "CAD", "AUD", "THB", "HUF", "DKK"
]

struct WidgetStorage {
    static let shared = UserDefaults.standard
    static let amountKey = "widgetCustomAmount"
    
    static var amount: Double {
        get { return shared.double(forKey: amountKey) }
        set { shared.set(newValue, forKey: amountKey) }
    }
}

struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
}

// --- 2. KONFIGURACJA LISTY ROZWIJANEJ (AppEntity) ---

struct CurrencyEntity: AppEntity {
    let id: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Waluta"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
    
    static var defaultQuery = CurrencyQuery()
}

struct CurrencyQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        identifiers.map { CurrencyEntity(id: $0) }
    }
    
    func entities(matching string: String) async throws -> [CurrencyEntity] {
        allCurrencies
            .filter { $0.localizedCaseInsensitiveContains(string) }
            .map { CurrencyEntity(id: $0) }
    }
    
    func suggestedEntities() async throws -> [CurrencyEntity] {
        allCurrencies.map { CurrencyEntity(id: $0) }
    }
}

// --- 3. KONFIGURACJA WIDŻETU (Intent) ---

@available(iOS 17.0, *)
struct CurrencySelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Konfiguracja Walut"
    static var description = IntentDescription("Wybierz waluty do przeliczania.")

    // POPRAWKA: Typy muszą być opcjonalne (CurrencyEntity?)
    @Parameter(title: "Z Waluty")
    var fromCurrency: CurrencyEntity?

    @Parameter(title: "Na Walutę")
    var toCurrency: CurrencyEntity?
    
    // Wartości domyślne
    init() {
        self.fromCurrency = CurrencyEntity(id: "THB")
        self.toCurrency = CurrencyEntity(id: "PLN")
    }
    
    init(from: String, to: String) {
        self.fromCurrency = CurrencyEntity(id: from)
        self.toCurrency = CurrencyEntity(id: to)
    }
}

// --- 4. TIMELINE PROVIDER ---

struct SimpleEntry: TimelineEntry {
    let date: Date
    let rate: Double
    let amount: Double
    let from: String
    let to: String
}

@available(iOS 17.0, *)
struct Provider: AppIntentTimelineProvider {
    typealias Entry = SimpleEntry
    typealias Intent = CurrencySelectionIntent

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), rate: 4.0, amount: 100, from: "USD", to: "PLN")
    }

    func snapshot(for configuration: CurrencySelectionIntent, in context: Context) async -> SimpleEntry {
        // POPRAWKA: Bezpieczne rozpakowanie opcjonalnych wartości
        let fromCode = configuration.fromCurrency?.id ?? "USD"
        let toCode = configuration.toCurrency?.id ?? "PLN"
        
        let rate = await fetchRate(from: fromCode, to: toCode)
        return SimpleEntry(date: Date(), rate: rate, amount: WidgetStorage.amount, from: fromCode, to: toCode)
    }
    
    func timeline(for configuration: CurrencySelectionIntent, in context: Context) async -> Timeline<SimpleEntry> {
        // POPRAWKA: Bezpieczne rozpakowanie opcjonalnych wartości
        let fromCode = configuration.fromCurrency?.id ?? "USD"
        let toCode = configuration.toCurrency?.id ?? "PLN"
        
        let rate = await fetchRate(from: fromCode, to: toCode)
        let currentAmount = WidgetStorage.amount
        
        let entry = SimpleEntry(date: .now, rate: rate, amount: currentAmount, from: fromCode, to: toCode)
        
        // Odświeżanie co godzinę
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchRate(from: String, to: String) async -> Double {
        if from == to { return 1.0 }
        let urlString = "https://api.frankfurter.app/latest?from=\(from)&to=\(to)"
        guard let url = URL(string: urlString) else { return 0.0 }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            return response.rates[to] ?? 0.0
        } catch {
            return 0.0
        }
    }
}

// --- 5. GŁÓWNY WIDOK WIDŻETU ---

struct WidgetExtensionEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// --- WIDOKI SYSTEMOWE (Ekran Główny) ---

struct SmallWidgetView: View {
    var entry: Provider.Entry
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.from) → \(entry.to)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 4)
            
            KeypadView(buttonHeight: 20, fontSize: 12, spacing: 2)
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
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
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
            
            KeypadView(buttonHeight: 30, fontSize: 16, spacing: 5)
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
            // GÓRA: Ekran Wyników
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Label(entry.from, systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Label(entry.to, systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(.green.opacity(0.8))
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
            
            // DÓŁ: Klawiatura
            KeypadView(buttonHeight: 40, fontSize: 22, spacing: 8)
                .padding(.bottom, 4)
        }
        .padding()
        .widgetURL(URL(string: "currencyconverter://open"))
    }
}

// --- WIDOKI EKRANU BLOKADY (Lock Screen) ---

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
                Text(entry.to)
                    .font(.caption2.bold())
                Text(String(format: "%.2f", entry.rate))
                    .font(.system(size: 10))
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

// --- WSPÓLNA KLAWIATURA ---

struct KeypadView: View {
    var buttonHeight: CGFloat
    var fontSize: CGFloat
    var spacing: CGFloat
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(1...9, id: \.self) { num in
                NumberButton(number: num, height: buttonHeight, fontSize: fontSize)
            }
            
            Button(intent: ClearAmountIntent()) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.2))
                    Image(systemName: "trash")
                        .font(.system(size: fontSize * 0.7))
                        .foregroundStyle(Color.red.opacity(0.8))
                }
                .frame(height: buttonHeight)
            }
            .buttonStyle(.plain)
            
            NumberButton(number: 0, height: buttonHeight, fontSize: fontSize)
            
            Button(intent: RefreshIntent()) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.2))
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: fontSize * 0.7))
                        .foregroundStyle(Color.blue.opacity(0.8))
                }
                .frame(height: buttonHeight)
            }
            .buttonStyle(.plain)
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
                Text("\(number)")
                    .font(.system(size: fontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(height: height)
        }
        .buttonStyle(.plain)
    }
}

// --- POMOCNIKI ---

func formatAmount(_ val: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: val)) ?? "0"
}

// --- INTENCJE ---

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
        return .result()
    }
}

// --- PUNKT WEJŚCIA ---

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
        .description("Przeliczaj waluty bezpośrednio na ekranie.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
