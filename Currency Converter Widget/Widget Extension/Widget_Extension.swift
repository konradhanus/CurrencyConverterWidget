import WidgetKit
import SwiftUI
import AppIntents

// --- Pomocnik do przechowywania stanu (kwota) ---
struct WidgetStorage {
    // Używamy standardowych UserDefaults. W prawdziwej aplikacji z App Group użyłbyś suiteName.
    static let shared = UserDefaults.standard
    static let amountKey = "widgetCustomAmount"
    
    static var amount: Double {
        get {
            return shared.double(forKey: amountKey)
        }
        set {
            shared.set(newValue, forKey: amountKey)
        }
    }
}

// --- Struktura do dekodowania odpowiedzi z API ---
struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
}

// --- Dostawca Danych dla Widżetu ---
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), rate: 0.123, amount: 100, from: "THB", to: "PLN")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        Task {
            let rate = await fetchRate(from: "THB", to: "PLN")
            let currentAmount = WidgetStorage.amount == 0 ? 1 : WidgetStorage.amount // Domyślnie 1 jeśli 0 w snapshot
            let entry = SimpleEntry(date: Date(), rate: rate, amount: currentAmount, from: "THB", to: "PLN")
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        Task {
            let rate = await fetchRate(from: "THB", to: "PLN")
            let currentAmount = WidgetStorage.amount
            
            // Jeśli kwota jest 0 (np. po wyczyszczeniu), wyświetlaj 0. Jeśli nic nie wpisano (start), to może 1?
            // Przyjmijmy: 0 to 0. Domyślny start aplikacji bez danych to 0.
            
            let entry = SimpleEntry(date: .now, rate: rate, amount: currentAmount, from: "THB", to: "PLN")
            
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
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
            print("Błąd pobierania w widżecie: \(error)")
            return 0.0
        }
    }
}

// Model danych dla widżetu
struct SimpleEntry: TimelineEntry {
    let date: Date
    let rate: Double
    let amount: Double
    let from: String
    let to: String
}

// --- Główny Widok Widżetu ---
struct WidgetExtensionEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        HStack(spacing: 0) {
            // Lewa strona: Wynik i info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(entry.from) → \(entry.to)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                
                Spacer()
                
                // Wyświetlanie wpisanej kwoty (wejście)
                Text(formatAmount(entry.amount))
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Wyświetlanie przeliczonej kwoty (wynik)
                let result = entry.amount * entry.rate
                Text(formatAmount(result))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Text("Kurs: \(String(format: "%.4f", entry.rate))")
                     .font(.caption2)
                     .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            .padding(.trailing, 8)
            
            // Prawa strona: Klawiatura (tylko w Medium, w Small uproszczona lub brak miejsca)
            if family == .systemMedium {
                Divider().background(.white.opacity(0.3))
                KeypadView()
                    .frame(width: 140)
                    .padding(.leading, 8)
            } else {
                // Wersja dla małego widżetu - bardzo uproszczona klawiatura nakładana?
                // W Small brakuje miejsca na pełną klawiaturę obok tekstu.
                // Spróbujmy zmieścić miniaturową siatkę na dole lub jako overlay.
                // Tu dla czytelności w Small zostawiamy tylko wynik i przyciski +/- prostsze,
                // ale użytkownik prosił o klawiaturę. W Small jest ciężko.
                // Zrobimy miniaturową wersję.
            }
        }
        .padding()
        .widgetURL(URL(string: "currencyconverter://open"))
        .overlay(alignment: .bottomTrailing) {
             if family == .systemSmall {
                 // W małym widżecie dajemy przycisk czyszczenia i może przykładowe "+10" zamiast pełnej klawiatury,
                 // bo przyciski 3x4 będą za małe do trafienia palcem (minimalny touch target).
                 // Ale spróbujmy dać kompaktową klawiaturę.
                 KeypadView(compact: true)
                     .opacity(0.2) // Tło interaktywne? Nie, to musi być widoczne.
                     .background(.black.opacity(0.4))
                     .cornerRadius(8)
                     .frame(width: 80, height: 100)
             }
        }
    }
    
    func formatAmount(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: val)) ?? "0"
    }
}

// --- Widok Klawiatury ---
struct KeypadView: View {
    var compact: Bool = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: compact ? 2 : 6) {
            ForEach(1...9, id: \.self) { num in
                Button(intent: TypeNumberIntent(num)) {
                    Text("\(num)")
                        .font(.system(size: compact ? 12 : 16, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: compact ? 20 : 30)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(compact ? 4 : 6)
                }
                .buttonStyle(.plain)
            }
            
            // Rząd dolny: C, 0, Odśwież
            Button(intent: ClearAmountIntent()) {
                Image(systemName: "trash")
                    .font(.system(size: compact ? 10 : 14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: compact ? 20 : 30)
                    .background(Color.red.opacity(0.4))
                    .cornerRadius(compact ? 4 : 6)
            }.buttonStyle(.plain)
            
            Button(intent: TypeNumberIntent(0)) {
                Text("0")
                    .font(.system(size: compact ? 12 : 16, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: compact ? 20 : 30)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(compact ? 4 : 6)
            }.buttonStyle(.plain)
            
            Button(intent: RefreshIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: compact ? 10 : 14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: compact ? 20 : 30)
                    .background(Color.blue.opacity(0.4))
                    .cornerRadius(compact ? 4 : 6)
            }.buttonStyle(.plain)
        }
    }
}

// --- Główna Definicja Widżetu z @main ---
@main
struct WidgetExtensionWidget: Widget {
    let kind: String = "Widget_Extension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Kalkulator Walut")
        .description("Szybki przelicznik z klawiaturą.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// --- INTENCJE (Akcje) ---

struct TypeNumberIntent: AppIntent {
    static var title: LocalizedStringResource = "Wpisz cyfrę"
    
    @Parameter(title: "Cyfra")
    var number: Int
    
    init() {}
    init(_ number: Int) { self.number = number }
    
    func perform() async throws -> some IntentResult {
        // Logika "kalkulatora": przesuwamy obecną liczbę w lewo i dodajemy cyfrę
        // np. było 12, wpisano 5 -> 125.
        // Ograniczamy do rozsądnej wielkości (np. < 1mld)
        let current = WidgetStorage.amount
        
        if current < 1_000_000 {
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
        WidgetCenter.shared.reloadTimelines(ofKind: "Widget_Extension")
        return .result()
    }
}