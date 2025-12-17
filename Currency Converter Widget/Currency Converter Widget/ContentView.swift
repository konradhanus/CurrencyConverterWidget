import SwiftUI
import WidgetKit

// --- 1. WSPÓŁDZIELONY MODEL DANYCH I LOGIKA ---

// UWAGA: Ta struktura musi być identyczna jak w Widget_Extension
struct ExpenseItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var amount: Double
    var currency: String
    var convertedAmount: Double
    var targetCurrency: String
    var date: Date
    var note: String? // Dodatkowe pole na notatkę
}

// Zarządzanie danymi (Musi używać tego samego App Group co Widget)
class ExpenseManager: ObservableObject {
    static let shared = ExpenseManager()
    
    // ZMIEŃ TO NA SWÓJ APP GROUP ID (musi być taki sam w Widżecie i Aplikacji)
    let suiteName = "group.com.currencyconverter.shared"
    let expensesKey = "savedExpensesList"
    
    @Published var expenses: [ExpenseItem] = []
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }
    
    init() {
        loadExpenses()
    }
    
    func loadExpenses() {
        if let data = defaults.data(forKey: expensesKey),
           let items = try? JSONDecoder().decode([ExpenseItem].self, from: data) {
            self.expenses = items.sorted(by: { $0.date > $1.date })
        }
    }
    
    func delete(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
        save()
    }
    
    func update(expense: ExpenseItem) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            save()
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            defaults.set(encoded, forKey: expensesKey)
            // Odśwież widżet po zmianie danych
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// --- 2. ViewModel Kalkulatora (Istniejący) ---

@MainActor
class ExchangeRateViewModel: ObservableObject {
    @Published var amount: Double = 100.0
    @Published var fromCurrency: String = "THB"
    @Published var toCurrency: String = "PLN"
    @Published var result: Double = 0.0
    @Published var exchangeRate: Double = 0.0
    @Published var isLoading: Bool = false
    @Published var lastUpdated: String = ""
    
    let allCurrencies = ["THB", "PLN", "USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD"]
    
    @Published var useCustomRate: Bool = false
    @Published var customRateString: String = "0.12"

    init() {
        Task { await fetchExchangeRate() }
    }
    
    func calculateResult() {
        let rateToUse = useCustomRate ? (Double(customRateString) ?? 0.0) : exchangeRate
        result = amount * rateToUse
    }
    
    func swapCurrencies() {
        let temp = fromCurrency
        fromCurrency = toCurrency
        toCurrency = temp
        Task { await fetchExchangeRate() }
    }

    func fetchExchangeRate() async {
        guard !isLoading else { return }
        
        if fromCurrency == toCurrency {
            self.exchangeRate = 1.0
            calculateResult()
            return
        }
        
        if useCustomRate { calculateResult(); return }

        isLoading = true
        let urlString = "https://api.frankfurter.app/latest?from=\(fromCurrency)&to=\(toCurrency)"
        
        do {
            guard let url = URL(string: urlString) else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            
            if let rate = response.rates[toCurrency] {
                self.exchangeRate = rate
                self.lastUpdated = formatDate(response.date)
                calculateResult()
            }
        } catch {
            print("Błąd: \(error)")
        }
        isLoading = false
    }
    
    private func formatDate(_ dateString: String) -> String {
        return dateString // Uproszczone dla czytelności
    }
}

struct ExchangeRateResponse: Codable {
    let date: String
    let rates: [String: Double]
}

// --- 3. WIDOKI APLIKACJI ---

struct ContentView: View {
    @StateObject private var expenseManager = ExpenseManager()
    
    init() {
        // Dostosowanie wyglądu TabBar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView {
            CalculatorView()
                .tabItem {
                    Label("Przelicznik", systemImage: "arrow.triangle.2.circlepath")
                }
            
            ExpensesView()
                .environmentObject(expenseManager)
                .tabItem {
                    Label("Wydatki", systemImage: "list.bullet.rectangle.portrait")
                }
        }
        .accentColor(.purple)
    }
}

// --- ZAKŁADKA 1: KALKULATOR ---

struct CalculatorView: View {
    @StateObject private var viewModel = ExchangeRateViewModel()
    @FocusState private var isAmountFieldFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                VStack(spacing: 25) {
                    Text("Konwerter Walut")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.primary.opacity(0.8))
                    
                    // Input
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Kwota").font(.footnote).foregroundColor(.secondary)
                        TextField("0", value: $viewModel.amount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold))
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                            .focused($isAmountFieldFocused)
                    }
                    
                    // Waluty
                    HStack {
                        picker(for: $viewModel.fromCurrency)
                        Button(action: viewModel.swapCurrencies) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .font(.title)
                                .foregroundColor(.accentColor)
                                .rotationEffect(viewModel.isLoading ? .degrees(180) : .zero)
                        }
                        picker(for: $viewModel.toCurrency)
                    }
                    
                    // Wynik
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Wynik").font(.footnote).foregroundColor(.secondary)
                        Text(viewModel.result, format: .currency(code: viewModel.toCurrency))
                            .font(.title.weight(.bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .onTapGesture { isAmountFieldFocused = false }
        .onChange(of: viewModel.fromCurrency) { _,_ in Task { await viewModel.fetchExchangeRate() } }
        .onChange(of: viewModel.toCurrency) { _,_ in Task { await viewModel.fetchExchangeRate() } }
        .onChange(of: viewModel.amount) { _,_ in viewModel.calculateResult() }
    }
    
    func picker(for selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(viewModel.allCurrencies, id: \.self) { Text($0) }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.2))
        .cornerRadius(10)
    }
}

// --- ZAKŁADKA 2: LISTA WYDATKÓW ---

struct ExpensesView: View {
    @EnvironmentObject var manager: ExpenseManager
    @State private var itemToDelete: IndexSet?
    @State private var showDeleteConfirmation = false
    @State private var editingItem: ExpenseItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if manager.expenses.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(manager.expenses) { item in
                            ExpenseRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingItem = item
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        if let index = manager.expenses.firstIndex(of: item) {
                                            itemToDelete = IndexSet(integer: index)
                                            showDeleteConfirmation = true
                                        }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Moje Wydatki")
            .sheet(item: $editingItem) { item in
                EditExpenseView(item: item) { updatedItem in
                    manager.update(expense: updatedItem)
                    editingItem = nil
                }
            }
            .confirmationDialog("Czy na pewno chcesz usunąć ten wydatek?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Usuń", role: .destructive) {
                    if let offsets = itemToDelete {
                        manager.delete(at: offsets)
                    }
                }
                Button("Anuluj", role: .cancel) {}
            }
            .onAppear {
                manager.loadExpenses()
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("Brak zapisanych wydatków")
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
            Text("Dodaj wydatki używając widżetu na ekranie głównym.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

struct ExpenseRow: View {
    let item: ExpenseItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.note?.isEmpty == false ? item.note! : "Bez opisu")
                    .font(.headline)
                    .foregroundColor(item.note?.isEmpty == false ? .primary : .secondary)
                
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.amount, format: .currency(code: item.currency))
                    .font(.body.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Text(item.convertedAmount, format: .currency(code: item.targetCurrency))
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

// --- EDYCJA WYDATKU ---

struct EditExpenseView: View {
    @State var item: ExpenseItem
    var onSave: (ExpenseItem) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Szczegóły")) {
                    TextField("Opis (np. Obiadu, Taxi)", text: Binding(
                        get: { item.note ?? "" },
                        set: { item.note = $0 }
                    ))
                    
                    DatePicker("Data", selection: $item.date)
                }
                
                Section(header: Text("Kwoty (Tylko do odczytu)")) {
                    HStack {
                        Text("Kwota oryginalna")
                        Spacer()
                        Text("\(item.amount, format: .number) \(item.currency)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Po przewalutowaniu")
                        Spacer()
                        Text("\(item.convertedAmount, format: .number) \(item.targetCurrency)")
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Edytuj Wydatek")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        onSave(item)
                    }
                }
            }
        }
    }
}