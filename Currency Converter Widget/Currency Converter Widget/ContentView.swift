import SwiftUI
import WidgetKit

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
        
        // Jeśli waluty są te same, kurs to 1
        if fromCurrency == toCurrency {
            self.exchangeRate = 1.0
            calculateResult()
            self.lastUpdated = "teraz"
            return
        }
        
        // Jeśli używamy własnego kursu, nie pobieraj danych
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
            // Tło z gradientem dla efektu "liquid"
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                
                // Główny kontener w stylu "glassmorphism"
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

    // MARK: - Subviews
    
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


// --- 3. KOD DLA WIDŻETÓW ---
/*
 
 KROK 1: Utwórz nowy cel (target) dla widżetu w Xcode.
 1. W Xcode wybierz: File -> New -> Target...
 2. Wyszukaj i wybierz "Widget Extension".
 3. Nazwij go np. "CurrencyConverterWidgetExtension". Upewnij się, że opcja "Include Live Activity" jest odznaczona (chyba że chcesz ją dodać później) i kliknij "Finish".
 
 KROK 2: Zastąp zawartość pliku, który Xcode właśnie utworzył (np. `CurrencyConverterWidgetExtension.swift`) poniższym kodem.
 
 UWAGA: Logika sieciowa w widżetach powinna być oszczędna. Poniższy kod pobiera dane raz na określony czas.
 
 */

/*
 
 // Plik: CurrencyConverterWidgetExtension.swift
 
 import WidgetKit
 import SwiftUI

 // --- Model Danych dla Widżetu ---
 struct WidgetExchangeRateResponse: Codable {
     let rates: [String: Double]
 }

 // --- Dostawca Linii Czasu dla Widżetu (TimelineProvider) ---
 struct Provider: TimelineProvider {
     // Dane tymczasowe, gdy widżet się ładuje
     func placeholder(in context: Context) -> SimpleEntry {
         SimpleEntry(date: Date(), rate: 0.1234, from: "THB", to: "PLN")
     }

     // Dane dla podglądu widżetu w galerii
     func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
         let entry = SimpleEntry(date: Date(), rate: 0.1234, from: "THB", to: "PLN")
         completion(entry)
     }

     // Dane aktualne i przyszłe aktualizacje
     func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
         Task {
             let from = "THB"
             let to = "PLN"
             let rate = await fetchRate(from: from, to: to)
             
             let entry = SimpleEntry(date: .now, rate: rate, from: from, to: to)
             
             // Ustalenie, kiedy widżet ma się odświeżyć (np. za godzinę)
             let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
             let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
             completion(timeline)
         }
     }
     
     private func fetchRate(from: String, to: String) async -> Double {
         let urlString = "https://api.frankfurter.app/latest?from=\(from)&to=\(to)"
         guard let url = URL(string: urlString) else { return 0.0 }

         do {
             let (data, _) = try await URLSession.shared.data(from: url)
             let response = try JSONDecoder().decode(WidgetExchangeRateResponse.self, from: data)
             return response.rates[to] ?? 0.0
         } catch {
             print("Błąd pobierania w widżecie: \(error)")
             return 0.0
         }
     }
 }

 // --- Wpis Linii Czasu (TimelineEntry) ---
 struct SimpleEntry: TimelineEntry {
     let date: Date
     let rate: Double
     let from: String
     let to: String
 }

 // --- Widok Widżetu ---
 struct CurrencyConverterWidgetEntryView : View {
     var entry: Provider.Entry
     
     // Widok dla mniejszych widżetów na ekranie głównym
     @ViewBuilder
     var body: some View {
         ZStack {
             LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
             
             VStack(alignment: .leading, spacing: 5) {
                 Text("\(entry.from) → \(entry.to)")
                     .font(.caption.weight(.bold))
                     .foregroundColor(.white.opacity(0.8))
                 
                 Text(String(format: "%.4f", entry.rate))
                     .font(.title2.weight(.semibold))
                     .foregroundColor(.white)
                     .minimumScaleFactor(0.5)
                     .lineLimit(1)
                 
                 Text("1 \(entry.from)")
                      .font(.caption2)
                      .foregroundColor(.white.opacity(0.7))
             }
             .padding()
         }
     }
 }
 
 // --- Konfiguracja dla ekranu blokady (Accessory Widget) ---
 struct AccessoryWidgetView: View {
     var entry: Provider.Entry

     var body: some View {
         VStack(alignment: .leading) {
             Text("\(entry.from) → \(entry.to)")
                 .font(.headline)
             Text(String(format: "%.4f", entry.rate))
                 .font(.body)
         }
     }
 }


 // --- Główna Struktura Widżetu ---
 struct CurrencyConverterWidget: Widget {
     let kind: String = "CurrencyConverterWidget"

     var body: some WidgetConfiguration {
         StaticConfiguration(kind: kind, provider: Provider()) { entry in
             CurrencyConverterWidgetEntryView(entry: entry)
         }
         .configurationDisplayName("Konwerter Walut")
         .description("Szybko sprawdź aktualny kurs walut.")
         .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular]) // Dodajemy wsparcie dla ekranu blokady
     }
 }
 
 */