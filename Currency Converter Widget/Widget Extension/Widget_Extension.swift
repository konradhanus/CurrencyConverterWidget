import WidgetKit
import SwiftUI
import AppIntents

// --- Pomocnik do przechowywania stanu (kwota) ---
struct WidgetStorage {
    static let shared = UserDefaults.standard
    static let amountKey = "widgetCustomAmount"
    
    static var amount: Double {
        get { return shared.double(forKey: amountKey) }
        set { shared.set(newValue, forKey: amountKey) }
    }
}

// --- Struktura do dekodowania odpowiedzi z API ---
struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
}

// --- KONFIGURACJA WIDŻETU (App Intent) ---
@available(iOS 17.0, *)
struct CurrencySelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Konfiguracja Walut"
    static var description = IntentDescription("Wybierz waluty do przeliczania.")

    @Parameter(title: "Z Waluty", default: "THB")
    var fromCurrency: String

    @Parameter(title: "Na Walutę", default: "PLN")
    var toCurrency: String
    
    init() {
        self.fromCurrency = "THB"
        self.toCurrency = "PLN"
    }
    
    init(from: String, to: String) {
        self.fromCurrency = from
        self.toCurrency = to
    }
}

// --- MODEL DANYCH ---
struct SimpleEntry: TimelineEntry {
    let date: Date
    let rate: Double
    let amount: Double
    let from: String
    let to: String
}

// --- DOSTAWCA DANYCH (Provider) ---
// POPRAWKA: AppIntentTimelineProvider (bez 's' w środku)
@available(iOS 17.0, *)
struct Provider: AppIntentTimelineProvider {
    
    // Te aliasy pomagają kompilatorowi zrozumieć typy
    typealias Entry = SimpleEntry
    typealias Intent = CurrencySelectionIntent

    // Context jest teraz poprawnie rozpoznawany dzięki AppIntentTimelineProvider
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), rate: 0.12, amount: 100, from: "THB", to: "PLN")
    }

    func snapshot(for configuration: CurrencySelectionIntent, in context: Context) async -> SimpleEntry {
        let rate = await fetchRate(from: configuration.fromCurrency, to: configuration.toCurrency)
        return SimpleEntry(date: Date(), rate: rate, amount: WidgetStorage.amount, from: configuration.fromCurrency, to: configuration.toCurrency)
    }
    
    func timeline(for configuration: CurrencySelectionIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let rate = await fetchRate(from: configuration.fromCurrency, to: configuration.toCurrency)
        let currentAmount = WidgetStorage.amount
        
        let entry = SimpleEntry(date: .now, rate: rate, amount: currentAmount, from: configuration.fromCurrency, to: configuration.toCurrency)
        
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
            print("Błąd pobierania: \(error)")
            return 0.0
        }
    }
}

// --- GŁÓWNY WIDOK WIDŻETU ---
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
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// --- WIDOK: MAŁY (Small) ---
struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.from) → \(entry.to)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(formatAmount(entry.amount))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                let result = entry.amount * entry.rate
                Text(formatAmount(result))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            .padding(.bottom, 4)
            
            KeypadView(buttonHeight: 20, fontSize: 12, spacing: 2)
        }
        .widgetURL(URL(string: "currencyconverter://open"))
    }
}

// --- WIDOK: ŚREDNI (Medium) ---
struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.from)
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.blue.opacity(0.8))
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    Text(entry.to)
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.purple.opacity(0.8))
                }
                
                Spacer()
                
                Text(formatAmount(entry.amount))
                    .font(.system(size: 20, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                let result = entry.amount * entry.rate
                Text(formatAmount(result))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Spacer()
                Text("1 \(entry.from) ≈ \(String(format: "%.3f", entry.rate)) \(entry.to)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            KeypadView(buttonHeight: 30, fontSize: 16, spacing: 5)
                .frame(width: 130)
        }
        .padding()
        .widgetURL(URL(string: "currencyconverter://open"))
    }
}

// --- WIDOK: DUŻY (Large) ---
struct LargeWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Label(entry.from, systemImage: "arrow.up.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Label(entry.to, systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.green.opacity(0.8))
                }
                .font(.caption.weight(.bold))
                
                Divider().background(.white.opacity(0.2))
                
                Text(formatAmount(entry.amount))
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .minimumScaleFactor(0.8)
                
                let result = entry.amount * entry.rate
                Text(formatAmount(result))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                HStack {
                    Spacer()
                    Text("Kurs: \(String(format: "%.4f", entry.rate))")
                        .font(.caption2)
                        .padding(4)
                        .background(.white.opacity(0.1))
                        .cornerRadius(4)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
            
            KeypadView(buttonHeight: 45, fontSize: 24, spacing: 10)
        }
        .padding()
        .widgetURL(URL(string: "currencyconverter://open"))
    }
}

// --- KLAWIATURA (Wspólna) ---
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.2))
                    Image(systemName: "trash")
                        .font(.system(size: fontSize * 0.7))
                        .foregroundColor(.red.opacity(0.8))
                }
                .frame(height: buttonHeight)
            }
            .buttonStyle(.plain)
            
            NumberButton(number: 0, height: buttonHeight, fontSize: fontSize)
            
            Button(intent: RefreshIntent()) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.2))
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: fontSize * 0.7))
                        .foregroundColor(.blue.opacity(0.8))
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.1))
                Text("\(number)")
                    .font(.system(size: fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(height: height)
        }
        .buttonStyle(.plain)
    }
}

// --- FORMATOWANIE ---
func formatAmount(_ val: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: val)) ?? "0"
}

// --- INTENCJE (Akcje) ---

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

// --- PUNKT WEJŚCIA WIDŻETU ---
@main
struct WidgetExtensionWidget: Widget {
    let kind: String = "Widget_Extension"

    var body: some WidgetConfiguration {
        // AppIntentConfiguration (Singular) - to jest kluczowe dla iOS 17
        AppIntentConfiguration(kind: kind, intent: CurrencySelectionIntent.self, provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Kalkulator Walut")
        .description("Edytuj widżet, aby zmienić waluty.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
