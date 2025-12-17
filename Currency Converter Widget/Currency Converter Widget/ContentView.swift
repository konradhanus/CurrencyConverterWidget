
import SwiftUI
import WidgetKit
import AppIntents // Potrzebne dla interaktywnych widżetów

// --- 1. Model Danych i Logika Aplikacji ---

// Struktura do dekodowania odpowiedzi z API
struct ExchangeRateResponse: Codable {
    let amount: Double
    let base: String
    let date: String
    let rates: [String: Double]
}

// ViewModel zarządzający stanem i logiką
@MainActor
class ExchangeRateViewModel: ObservableObject {
    @Published var amount: Double = 100.0
    @Published var fromCurrency: String = "THB"
    @Published var toCurrency: String = "PLN"
    @Published var result: Double = 0.0
    @Published var exchangeRate: Double = 0.0
    @Published var isLoading: Bool = false
    @Published var lastUpdated: String = ""
    
    // Lista popularnych walut
    let allCurrencies = ["THB", "PLN", "USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD"]
    
    // Ustawienia dla własnego kursu
    @Published var useCustomRate: Bool = false
    @Published var customRateString: String = "0.12"

    init() {
        Task {
            await fetchExchangeRate()
        }
    }
    
    // Oblicza wynik na podstawie aktualnych danych
    func calculateResult() {
        let rateToUse = useCustomRate ? (Double(customRateString) ?? 0.0) : exchangeRate
        result = amount * rateToUse
    }
    
    // Funkcja do zamiany walut miejscami
    func swapCurrencies() {
        let tempCurrency = fromCurrency
        fromCurrency = toCurrency
        toCurrency = tempCurrency
        Task {
            await fetchExchangeRate()
        }
    }

    // Funkcja pobierająca kursy walut z API
    func fetchExchangeRate() async {
        guard !isLoading else { return }
        
        if fromCurrency == toCurrency {
            self.exchangeRate = 1.0
            calculateResult()
            self.lastUpdated = "teraz"
            return
        }
        
        if useCustomRate {
            calculateResult()
            return
        }

        isLoading = true
        
        let urlString = "https://api.frankfurter.app/latest?from=\(fromCurrency)&to=\(toCurrency)"
        guard let url = URL(string: urlString) else {
            print("Błędny URL")
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            
            if let rate = response.rates[toCurrency] {
                self.exchangeRate = rate
                self.lastUpdated = formatDate(response.date)
                calculateResult()
            }
        } catch {
            print("Błąd pobierania lub dekodowania danych: \(error)")
        }
        
        isLoading = false
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "N/A"
    }
}

// --- 2. Główny Widok Aplikacji (UI) ---

struct ContentView: View {
    @StateObject private var viewModel = ExchangeRateViewModel()
    @FocusState private var isAmountFieldFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                
                VStack(spacing: 25) {
                    headerView
                    amountInputView
                    currencySelectionView
                    resultView
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal)
                
                settingsView
                
                Spacer()
                
                footerView
            }
        }
        .onTapGesture {
             isAmountFieldFocused = false
        }
        .onChange(of: viewModel.fromCurrency) { _,_ in Task { await viewModel.fetchExchangeRate() } }
        .onChange(of: viewModel.toCurrency) { _,_ in Task { await viewModel.fetchExchangeRate() } }
        .onChange(of: viewModel.amount) { _,_ in viewModel.calculateResult() }
        .onChange(of: viewModel.useCustomRate) { _,_ in Task { await viewModel.fetchExchangeRate() } }
        .onChange(of: viewModel.customRateString) { _,_ in viewModel.calculateResult() }
    }
    
    private var headerView: some View {
        Text("Konwerter Walut")
            .font(.largeTitle.weight(.bold))
            .foregroundColor(.primary.opacity(0.8))
    }
    
    private var amountInputView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Kwota")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            TextField("Wpisz kwotę", value: $viewModel.amount, format: .number)
                .keyboardType(.decimalPad)
                .font(.title2.weight(.semibold))
                .padding(12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
                .focused($isAmountFieldFocused)
        }
    }
    
    private var currencySelectionView: some View {
        HStack(spacing: 15) {
            currencyPicker(for: $viewModel.fromCurrency)
            
            Button(action: viewModel.swapCurrencies) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                    .rotationEffect(viewModel.isLoading ? .degrees(180) : .zero)
                    .animation(.easeInOut, value: viewModel.isLoading)
            }
            
            currencyPicker(for: $viewModel.toCurrency)
        }
    }
    
    private func currencyPicker(for currency: Binding<String>) -> some View {
        Picker("", selection: currency) {
            ForEach(viewModel.allCurrencies, id: \.self) {
                Text($0)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.2))
        .cornerRadius(10)
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Wynik")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Text(viewModel.result, format: .currency(code: viewModel.toCurrency))
                .font(.title.weight(.bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var settingsView: some View {
        VStack {
            Toggle(isOn: $viewModel.useCustomRate) {
                Text("Użyj własnego kursu")
                    .font(.subheadline)
            }
            
            if viewModel.useCustomRate {
                TextField("Własny kurs", text: $viewModel.customRateString)
                    .keyboardType(.decimalPad)
                    .padding(8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.top, 5)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.8))
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    private var footerView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Text("Kurs: 1 \(viewModel.fromCurrency) = \(viewModel.exchangeRate, specifier: "%.4f") \(viewModel.toCurrency)")
                    .font(.caption)
                Text("Ostatnia aktualizacja: \(viewModel.lastUpdated)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


// --- 3. KOD DLA INTERAKTYWNYCH WIDŻETÓW (iOS 17+) ---
/*
 
 KROK 1: Utwórz nowy cel (target) dla widżetu w Xcode.
 1. W Xcode wybierz: File -> New -> Target...
 2. Wyszukaj i wybierz "Widget Extension".
 3. Nazwij go np. "CurrencyConverterWidgetExtension". Upewnij się, że opcja "Include Live Activity" jest odznaczona i kliknij "Finish".
 
 KROK 2: Zastąp zawartość pliku, który Xcode właśnie utworzył (np. `CurrencyConverterWidgetExtension.swift`) poniższym kodem.
 
 */

/*
 
 // Plik: CurrencyConverterWidgetExtension.swift
 
 import WidgetKit
 import SwiftUI
 import AppIntents

 // --- Konfiguracja Widżetu (Wybór Walut) ---

 struct CurrencySelectionIntent: WidgetConfigurationIntent {
     static var title: LocalizedStringResource = "Wybierz Waluty"
     static var description = IntentDescription("Wybierz parę walut do wyświetlenia w widżecie.")

     @Parameter(title: "Waluta Źródłowa", default: "THB")
     var fromCurrency: String

     @Parameter(title: "Waluta Docelowa", default: "PLN")
     var toCurrency: String
 }
 
 // --- Dane i Logika Widżetu ---

 struct Provider: AppIntentsTimelineProvider {
     // Dane tymczasowe
     func placeholder(in context: Context) -> SimpleEntry {
         SimpleEntry(date: Date(), rate: 0.12, from: "THB", to: "PLN")
     }

     // Dane dla podglądu
     func snapshot(for configuration: CurrencySelectionIntent, in context: Context) async -> SimpleEntry {
         let rate = await fetchRate(from: configuration.fromCurrency, to: configuration.toCurrency)
         return SimpleEntry(date: Date(), rate: rate, from: configuration.fromCurrency, to: configuration.toCurrency)
     }
     
     // Logika odświeżania widżetu
     func timeline(for configuration: CurrencySelectionIntent, in context: Context) async -> Timeline<SimpleEntry> {
         let rate = await fetchRate(from: configuration.fromCurrency, to: configuration.toCurrency)
         let entry = SimpleEntry(date: .now, rate: rate, from: configuration.fromCurrency, to: configuration.toCurrency)
         
         let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
         return Timeline(entries: [entry], policy: .after(nextUpdate))
     }
     
     // Funkcja pomocnicza do pobierania kursu
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
 
 // Model danych dla pojedynczego wpisu w historii widżetu
 struct SimpleEntry: TimelineEntry {
     let date: Date
     let rate: Double
     let from: String
     let to: String
 }
 
 // --- Widok Widżetu ---
 
 struct CurrencyConverterWidgetEntryView : View {
     var entry: Provider.Entry
     
     @Environment(\.widgetFamily) var family

     var body: some View {
         switch family {
         case .accessoryRectangular:
             AccessoryRectangularView(entry: entry)
         default:
             DefaultWidgetView(entry: entry)
         }
     }
 }
 
 // Widok dla ekranu głównego (mały, średni)
 struct DefaultWidgetView: View {
     var entry: Provider.Entry
     
     var body: some View {
         VStack {
             HStack {
                 Text("\(entry.from) → \(entry.to)")
                     .font(.caption.weight(.bold))
                 Spacer()
                 // Przycisk do odświeżania
                 Button(intent: RefreshIntent()) {
                     Image(systemName: "arrow.clockwise")
                 }
                 .tint(.white.opacity(0.8))
             }
             
             Spacer()
             
             Text(String(format: "%.4f", entry.rate))
                 .font(.system(size: 36, weight: .semibold, design: .rounded))
                 .minimumScaleFactor(0.5)
                 .lineLimit(1)
             
             Spacer()
             
             HStack {
                 Text("1 \(entry.from)")
                     .font(.caption2)
                 Spacer()
                 // Przycisk do zamiany walut - zmienia konfigurację
                 Button(intent: SwapCurrenciesIntent(from: entry.from, to: entry.to)) {
                     Image(systemName: "arrow.left.arrow.right")
                 }
                 .tint(.white.opacity(0.8))
             }
         }
         .foregroundColor(.white)
         .padding()
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
     }
 }
 
 // Widok dla ekranu blokady
 struct AccessoryRectangularView: View {
     var entry: Provider.Entry
     
     var body: some View {
         VStack(alignment: .leading) {
             Text("\(entry.from) → \(entry.to)")
                 .font(.headline)
             Text(String(format: "%.4f", entry.rate))
         }
     }
 }
 
 // --- Główna Struktura Widżetu ---

 struct CurrencyConverterWidget: Widget {
     let kind: String = "CurrencyConverterWidget"

     var body: some WidgetConfiguration {
         AppIntentsConfiguration(kind: kind, intent: CurrencySelectionIntent.self, provider: Provider()) { entry in
             CurrencyConverterWidgetEntryView(entry: entry)
                 .containerBackground(.fill.tertiary, for: .widget) // Standardowe tło
         }
         .configurationDisplayName("Kurs Walut")
         .description("Śledź wybrany kurs i odświeżaj go ręcznie.")
         .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
     }
 }

 // --- Logika Interakcji (AppIntents) ---

 // Intent do odświeżania
 struct RefreshIntent: AppIntent {
     static var title: LocalizedStringResource = "Odśwież kurs"
     
     func perform() async throws -> some IntentResult {
         // Powoduje ponowne załadowanie timeline'u dla widżetu
         WidgetCenter.shared.reloadTimelines(ofKind: "CurrencyConverterWidget")
         return .result()
     }
 }

 // Intent do zamiany walut
 struct SwapCurrenciesIntent: AppIntent {
     static var title: LocalizedStringResource = "Zamień Waluty"
     
     @Parameter(title: "From Currency")
     var from: String
     
     @Parameter(title: "To Currency")
     var to: String
     
     init(from: String, to: String) {
         self.from = from
         self.to = to
     }
     
     init() {}
     
     func perform() async throws -> some IntentResult {
         // Tworzymy nową konfigurację z zamienionymi walutami
         let newConfiguration = CurrencySelectionIntent()
         newConfiguration.fromCurrency = self.to
         newConfiguration.toCurrency = self.from
         
         // Aktualizujemy konfigurację widżetu
         try await newConfiguration.updateConfiguration()
         return .result()
     }
 }

 // Potrzebne do dekodowania odpowiedzi z API w widżecie
 struct ExchangeRateResponse: Codable {
     let rates: [String: Double]
 }
 
 */
