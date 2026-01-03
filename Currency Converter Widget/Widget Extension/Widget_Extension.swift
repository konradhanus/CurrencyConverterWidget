
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
    static let configFromKey = "widgetConfigFromCurrency"
    static let configToKey = "widgetConfigToCurrency"
    static let widgetLanguageKey = "widgetConfigLanguage"
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
    
    static var configFrom: String? {
        get { return shared.string(forKey: configFromKey) }
        set { shared.set(newValue, forKey: configFromKey) }
    }
    
    static var configTo: String? {
        get { return shared.string(forKey: configToKey) }
        set { shared.set(newValue, forKey: configToKey) }
    }
    
    static var widgetLanguage: String? {
        get { return shared.string(forKey: widgetLanguageKey) }
        set { shared.set(newValue, forKey: widgetLanguageKey) }
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
        
        // Handle Language Configuration
        let configLang = configuration.language.rawValue
        if WidgetStorage.widgetLanguage != configLang {
             WidgetStorage.widgetLanguage = configLang
        }
        
        // Force update localization manager immediately so the view renders with new language
        LocalizationManager.shared.updateFromSettings()
        
        // Check if configuration has changed since last time
        // or if it's the very first run (WidgetStorage.configFrom is nil)
        if configFrom != WidgetStorage.configFrom || configTo != WidgetStorage.configTo {
            WidgetStorage.activeFrom = configFrom
            WidgetStorage.activeTo = configTo
            WidgetStorage.configFrom = configFrom
            WidgetStorage.configTo = configTo
            
            // Invalidate cache for new pair
            WidgetStorage.lastFetchDate = Date.distantPast
            let cacheKey = "rate_\(configFrom)_\(configTo)"
            WidgetStorage.rate = WidgetStorage.shared.double(forKey: cacheKey)
        }
        
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
        
        let cacheKey = "rate_\(from)_\(to)"
        
        // 1. Try to use very fresh data from memory/cache if same pair
        let isSamePair = (WidgetStorage.activeFrom == from && WidgetStorage.activeTo == to)
        let hasRate = WidgetStorage.rate > 0
        let lastUpdate = WidgetStorage.lastFetchDate ?? Date.distantPast
        let isFresh = Date().timeIntervalSince(lastUpdate) < 3600
        
        if isSamePair && hasRate && isFresh {
            return WidgetStorage.rate
        }
        
        // 2. Try network
        let urlString = "https://api.frankfurter.app/latest?from=\(from)&to=\(to)"
        
        do {
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            let newRate = response.rates[to] ?? 0.0
            
            if newRate > 0 {
                WidgetStorage.rate = newRate
                WidgetStorage.lastFetchDate = Date()
                WidgetStorage.activeFrom = from
                WidgetStorage.activeTo = to
                
                // Cache specifically for this pair (shared with App)
                WidgetStorage.shared.set(newRate, forKey: cacheKey)
                
                return newRate
            }
        } catch {
            print("Błąd sieci: \(error)")
        }
        
        // 3. Fallback: Try specific cache for this pair
        let cachedSpecific = WidgetStorage.shared.double(forKey: cacheKey)
        if cachedSpecific > 0 {
            WidgetStorage.rate = cachedSpecific // Update active rate to match
            return cachedSpecific
        }
        
        // 4. Ultimate fallback
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
    @EnvironmentObject var loc: LocalizationManager
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                Text(loc.localized("saved_success"))
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
                HStack(alignment: .bottom, spacing: 2) {
                    Text(formatAmount(result))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    Text(entry.from)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            
            KeypadView(buttonHeight: 20, fontSize: 12, spacing: 2, showSaveButton: false)
        }
        .widgetURL(URL(string: "currencyconverter://open?from=\(entry.from)&to=\(entry.to)"))
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
        .widgetURL(URL(string: "currencyconverter://open?from=\(entry.from)&to=\(entry.to)"))
    }
}

struct LargeWidgetView: View {
    var entry: Provider.Entry
    @EnvironmentObject var loc: LocalizationManager
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 2) {
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
                
                Divider().background(.white.opacity(0.2)).padding(.vertical, 4)
                Spacer(minLength: 0)
                
                Text(formatAmount(entry.amount))
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                
                let result = entry.amount * entry.rate
                Text(formatAmount(result))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Text("\(loc.localized("rate_label")) \(String(format: "%.4f", entry.rate))")
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
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 8)
            
            KeypadView(buttonHeight: 38, fontSize: 22, spacing: 6, showSaveButton: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .widgetURL(URL(string: "currencyconverter://open?from=\(entry.from)&to=\(entry.to)"))
    }
}

// --- REST OF VIEWS ---

struct AccessoryRectangularView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(entry.from)
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(entry.to)
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                }
                
                Spacer(minLength: 0)
                
                let inputAmount = entry.amount > 0 ? entry.amount : 1.0
                let result = inputAmount * entry.rate
                
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formatAmount(inputAmount))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text("=")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(formatAmount(result))
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                    }
                    // Fallback for smaller space / long numbers
                    Text(formatAmount(result))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "currencyconverter://open?from=\(entry.from)&to=\(entry.to)"))
            
            // Swap button - Max height allowed in accessory
            Button(intent: SwapCurrenciesIntent()) {
                ZStack {
                    Color.white.opacity(0.15)
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(width: 32, height: 32) // Standard touch target size adaptation
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

struct AccessoryCircularView: View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Text(entry.from)
                    .font(.system(size: 14, weight: .bold))
                
                Text(String(format: "%.2f", entry.rate))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .minimumScaleFactor(0.8)
            }
        }
        .widgetURL(URL(string: "currencyconverter://open?from=\(entry.from)&to=\(entry.to)"))
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
    @EnvironmentObject var loc: LocalizationManager
    
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
                            Text(loc.localized("btn_save"))
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
    static var title: LocalizedStringResource = "intent_type_number"
    @Parameter(title: "intent_param_digit") var number: Int
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
    static var title: LocalizedStringResource = "intent_swap_title"
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
    static var title: LocalizedStringResource = "intent_clear"
    func perform() async throws -> some IntentResult {
        WidgetStorage.amount = 0
        return .result()
    }
}

struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "intent_refresh"
    func perform() async throws -> some IntentResult {
        WidgetStorage.lastFetchDate = Date.distantPast
        return .result()
    }
}

struct SaveExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "intent_save"
    
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

enum WidgetLanguage: String, AppEnum {
    case system = "system"
    case english = "en"
    case polish = "pl"
    case german = "de"
    case dutch = "nl"
    case spanish = "es"
    case french = "fr"
    case chinese = "zh"
    case japanese = "ja"
    case portuguese = "pt"
    case czech = "cs"
    case slovak = "sk"
    case croatian = "hr"
    case russian = "ru"
    case serbian = "sr"
    case ukrainian = "uk"
    case thai = "th"
    case hindi = "hi"
    case greek = "el"
    case italian = "it"
    case arabic = "ar"
    case hungarian = "hu"
    case finnish = "fi"
    case icelandic = "is"
    case norwegian = "no"
    case swedish = "sv"
    case romanian = "ro"
    case mongolian = "mn"
    case korean = "ko"
    case turkish = "tr"
    case danish = "da"
    case hebrew = "he"
    case indonesian = "id"
    case vietnamese = "vi"
    case malay = "ms"
    case filipino = "tl"
    case bulgarian = "bg"
    case lithuanian = "lt"
    case latvian = "lv"
    case estonian = "et"
    case slovenian = "sl"
    case catalan = "ca"
    case swahili = "sw"
    case georgian = "ka"
    case albanian = "sq"
    case macedonian = "mk"
    case afrikaans = "af"
    case khmer = "km"
    case persian = "fa"
    case urdu = "ur"
    case bengali = "bn"
    case punjabi = "pa"
    case tamil = "ta"
    case telugu = "te"
    case marathi = "mr"
    case gujarati = "gu"
    case kannada = "kn"
    case malayalam = "ml"
    case sinhala = "si"
    case burmese = "my"
    case lao = "lo"
    case nepali = "ne"
    case armenian = "hy"
    case azerbaijani = "az"
    case kazakh = "kk"
    case uzbek = "uz"
    case turkmen = "tk"
    case kyrgyz = "ky"
    case tajik = "tg"
    case pashto = "ps"
    case kurdish = "ku"
    case amharic = "am"
    case somali = "so"
    case yoruba = "yo"
    case igbo = "ig"
    case hausa = "ha"
    case zulu = "zu"
    case xhosa = "xh"
    case bosnian = "bs"
    case maltese = "mt"
    case irish = "ga"
    case welsh = "cy"
    case basque = "eu"
    case galician = "gl"
    case belarusian = "be"
    case luxembourgish = "lb"
    case haitian = "ht"
    case javanese = "jv"
    case kinyarwanda = "rw"
    case malagasy = "mg"
    case shona = "sn"
    case sindhi = "sd"
    case uyghur = "ug"
    case tatar = "tt"
    case odia = "or"
    case assamese = "as"
    case tigrinya = "ti"
    case quechua = "qu"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "intent_conf_language"
    
    static var caseDisplayRepresentations: [WidgetLanguage : DisplayRepresentation] = [
        .system: "System",
        .english: "English",
        .polish: "Polski",
        .german: "Deutsch",
        .dutch: "Nederlands",
        .spanish: "Español",
        .french: "Français",
        .chinese: "中文",
        .japanese: "日本語",
        .portuguese: "Português",
        .czech: "Čeština",
        .slovak: "Slovenčina",
        .croatian: "Hrvatski",
        .russian: "Русский",
        .serbian: "Српски",
        .ukrainian: "Українська",
        .thai: "ไทย",
        .hindi: "हिन्दी",
        .greek: "Ελληνικά",
        .italian: "Italiano",
        .arabic: "العربية",
        .hungarian: "Magyar",
        .finnish: "Suomi",
        .icelandic: "Íslenska",
        .norwegian: "Norsk",
        .swedish: "Svenska",
        .romanian: "Română",
        .mongolian: "Монгол",
        .korean: "한국어",
        .turkish: "Türkçe",
        .danish: "Dansk",
        .hebrew: "עברית",
        .indonesian: "Bahasa Indonesia",
        .vietnamese: "Tiếng Việt",
        .malay: "Bahasa Melayu",
        .filipino: "Filipino",
        .bulgarian: "Български",
        .lithuanian: "Lietuvių",
        .latvian: "Latviešu",
        .estonian: "Eesti",
        .slovenian: "Slovenščina",
        .catalan: "Català",
        .swahili: "Kiswahili",
        .georgian: "ქართული",
        .albanian: "Shqip",
        .macedonian: "Македонски",
        .afrikaans: "Afrikaans",
        .khmer: "ភាសាខ្មែរ",
        .persian: "فارسی",
        .urdu: "اردو",
        .bengali: "বাংলা",
        .punjabi: "ਪੰਜਾਬੀ",
        .tamil: "தமிழ்",
        .telugu: "తెలుగు",
        .marathi: "मराठी",
        .gujarati: "ગુજરાતી",
        .kannada: "ಕನ್ನಡ",
        .malayalam: "മലയാളം",
        .sinhala: "සිംහල",
        .burmese: "မြန်မာ",
        .lao: "ລາវ",
        .nepali: "नेपाली",
        .armenian: "Հայերեն",
        .azerbaijani: "Azərbaycan",
        .kazakh: "Қазақша",
        .uzbek: "Oʻzbek",
        .turkmen: "Türkmen",
        .kyrgyz: "Кыргызча",
        .tajik: "Тоҷикӣ",
        .pashto: "پښتو",
        .kurdish: "Kurdî",
        .amharic: "ამჰარული",
        .somali: "Soomaali",
        .yoruba: "Yorùbá",
        .igbo: "Igbo",
        .hausa: "Hausa",
        .zulu: "isiZulu",
        .xhosa: "isiXhosa",
        .bosnian: "Bosanski",
        .maltese: "Malti",
        .irish: "Gaeilge",
        .welsh: "Cymraeg",
        .basque: "Euskara",
        .galician: "Galego",
        .belarusian: "Беларуская",
        .luxembourgish: "Lëtzebuergesch",
        .haitian: "Kreyòl Ayisyen",
        .javanese: "Jawa",
        .kinyarwanda: "Kinyarwanda",
        .malagasy: "Malagasy",
        .shona: "ChiShona",
        .sindhi: "سنڌي",
        .uyghur: "ئۇيغۇرچە",
        .tatar: "Татарча",
        .odia: "ଓଡ଼ିଆ",
        .assamese: "অসমীয়া",
        .tigrinya: "ትግርኛ",
        .quechua: "Runasimi"
    ]
}

struct CurrencyEntity: AppEntity {
    let id: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "entity_currency"
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
    static var title: LocalizedStringResource = "intent_conf_title"
    static var description = IntentDescription("intent_conf_desc")

    @Parameter(title: "intent_param_from")
    var fromCurrency: CurrencyEntity?

    @Parameter(title: "intent_param_to")
    var toCurrency: CurrencyEntity?
    
    @Parameter(title: "intent_conf_language", default: .system)
    var language: WidgetLanguage
    
    init() {
        self.fromCurrency = CurrencyEntity(id: "USD")
        self.toCurrency = CurrencyEntity(id: "PLN")
        self.language = .system
    }
}

let allCurrencies = ["AUD", "BGN", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD", "HUF", "IDR", "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR", "NOK", "NZD", "PHP", "PLN", "RON", "SEK", "SGD", "THB", "TRY", "USD", "ZAR"]

struct WidgetExtensionWidget: Widget {
    let kind: String = "Widget_Extension"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CurrencySelectionIntent.self, provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .environmentObject(LocalizationManager.shared)
                .environment(\.locale, LocalizationManager.shared.appLocale)
                .onAppear {
                    // Update language if changed in config or app settings
                    LocalizationManager.shared.updateFromSettings()
                }
        }
        .configurationDisplayName(String(localized: "widget_display_name"))
        .description(String(localized: "widget_description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct CurrencyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WidgetExtensionWidget()
        
        if #available(iOSApplicationExtension 18.0, *) {
            OpenAppControl()
        }
    }
}

@available(iOS 18.0, *)
struct OpenAppControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.currencyconverter.open") {
            ControlWidgetButton(action: OpenCurrencyConverterIntent()) {
                Label(String(localized: "widget_display_name"), systemImage: "arrow.right.arrow.left.circle")
            }
        }
        .displayName(LocalizedStringResource("widget_display_name"))
        .description(LocalizedStringResource("widget_description"))
    }
}

@available(iOS 16.0, *)
struct OpenCurrencyConverterIntent: AppIntent {
    static var title: LocalizedStringResource = "widget_display_name"
    static var openAppWhenRun: Bool = true
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
