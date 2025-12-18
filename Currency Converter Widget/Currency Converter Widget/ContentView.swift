import SwiftUI
import WidgetKit

// --- 1. WSPÓŁDZIELONY MODEL DANYCH I LOGIKA ---

struct ExpenseItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var amount: Double
    var currency: String
    var convertedAmount: Double
    var targetCurrency: String
    var date: Date
    var note: String?
}

class ExpenseManager: ObservableObject {
    static let shared = ExpenseManager()
    let suiteName = "group.com.currencyconverter.shared"
    let expensesKey = "savedExpensesList"
    
    @Published var expenses: [ExpenseItem] = []
    
    static let allCurrencies = ["THB", "PLN", "USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD", "CZK", "NOK", "SEK", "HUF", "DKK"]
    
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
    
    func addExpense(_ expense: ExpenseItem) {
        expenses.append(expense)
        expenses.sort(by: { $0.date > $1.date })
        saveToDefaults()
    }
    
    func update(expense: ExpenseItem) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            expenses.sort(by: { $0.date > $1.date })
            saveToDefaults()
        }
    }
    
    func delete(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
        saveToDefaults()
    }
    
    private func saveToDefaults() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            defaults.set(encoded, forKey: expensesKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    static func fetchExchangeRate(from fromCurrency: String, to toCurrency: String) async -> Double {
        if fromCurrency == toCurrency { return 1.0 }
        let urlString = "https://api.frankfurter.app/latest?from=\(fromCurrency)&to=\(toCurrency)"
        guard let url = URL(string: urlString) else { return 0.0 }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            return response.rates[toCurrency] ?? 0.0
        } catch {
            print("Error: \(error)")
            return 0.0
        }
    }
}

// --- 2. ViewModel ---

@MainActor
class ExchangeRateViewModel: ObservableObject {
    @Published var amount: Double = 0.0
    @Published var fromCurrency: String = "THB"
    @Published var toCurrency: String = "PLN"
    @Published var result: Double = 0.0
    @Published var exchangeRate: Double = 0.0
    @Published var isLoading: Bool = false
    @Published var lastUpdated: String = ""
    
    let allCurrencies = ExpenseManager.allCurrencies
    
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
                self.lastUpdated = "Teraz"
                calculateResult()
            }
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
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
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView {
            CalculatorView()
                .environmentObject(expenseManager)
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

// --- ZAKŁADKA 1: KALKULATOR (NOWY DESIGN) ---

struct CalculatorView: View {
    @StateObject private var viewModel = ExchangeRateViewModel()
    @EnvironmentObject var expenseManager: ExpenseManager
    @State private var showSaveConfirmation: Bool = false
    @State private var note: String = ""
    
    // Stan wpisywania (String pozwala łatwiej obsługiwać przecinki)
    @State private var inputString: String = "0"

    var body: some View {
        ZStack {
            // TŁO
            LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // GÓRNY PANEL (WYNIKI + INPUT)
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Konwerter Walut")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 10)
                        
                        // WYŚWIETLACZ KWOTY
                        VStack(spacing: 0) {
                            HStack {
                                Text(inputString)
                                    .font(.system(size: 50, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                Text(viewModel.fromCurrency)
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.bottom, 8)
                            }
                            
                            // WYNIK PRZELICZENIA
                            HStack {
                                Image(systemName: "equal")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.5))
                                Text(viewModel.result, format: .currency(code: viewModel.toCurrency))
                                    .font(.system(size: 30, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        
                        // WYBÓR WALUT
                        HStack(spacing: 12) {
                            CurrencyPill(currency: $viewModel.fromCurrency, all: viewModel.allCurrencies)
                            
                            Button(action: viewModel.swapCurrencies) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            
                            CurrencyPill(currency: $viewModel.toCurrency, all: viewModel.allCurrencies)
                        }
                        
                        // POLE OPISU
                        TextField("Dodaj opis (np. Taxi)", text: $note)
                            .padding(12)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .accentColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 30)
                            .placeholder(when: note.isEmpty) {
                                Text("Dodaj opis (np. Taxi)").foregroundColor(.white.opacity(0.5)).padding(.leading, 42)
                            }

                        // PRZYCISK ZAPISU
                        Button(action: saveExpense) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("Zapisz Wydatek")
                            }
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.9))
                            .cornerRadius(16)
                            .shadow(radius: 5)
                        }
                        .padding(.horizontal, 30)
                        .opacity(viewModel.amount > 0 ? 1 : 0.6)
                        .disabled(viewModel.amount <= 0)
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                        
                        // KLAWIATURA (Teraz jako część przewijanej listy)
                        AppKeypadView(onTap: handleKeypadInput)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 20)
                    }
                }
                .scrollIndicators(.hidden)
            }
            
            // OVERLAY POTWIERDZENIA
            if showSaveConfirmation {
                SuccessOverlayView()
            }
        }
        .onChange(of: viewModel.fromCurrency) { _,_ in Task { await viewModel.fetchExchangeRate() } }
        .onChange(of: viewModel.toCurrency) { _,_ in Task { await viewModel.fetchExchangeRate() } }
    }
    
    // Logika klawiatury
    func handleKeypadInput(_ key: String) {
        if key == "del" {
            if inputString.count > 1 {
                inputString.removeLast()
            } else {
                inputString = "0"
            }
        } else if key == "." {
            if !inputString.contains(".") {
                inputString += "."
            }
        } else {
            // Cyfra
            if inputString == "0" {
                inputString = key
            } else {
                // Limit długości
                if inputString.count < 9 {
                    inputString += key
                }
            }
        }
        
        // Aktualizacja ViewModel
        if let val = Double(inputString) {
            viewModel.amount = val
            viewModel.calculateResult()
        }
    }
    
    private func saveExpense() {
        guard viewModel.amount > 0 else { return }
        
        let newExpense = ExpenseItem(
            amount: viewModel.amount,
            currency: viewModel.fromCurrency,
            convertedAmount: viewModel.result,
            targetCurrency: viewModel.toCurrency,
            date: Date(),
            note: note.isEmpty ? nil : note
        )
        expenseManager.addExpense(newExpense)
        
        // Reset po zapisie
        note = ""
        inputString = "0"
        viewModel.amount = 0
        viewModel.calculateResult()
        
        showSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSaveConfirmation = false
        }
    }
}

// --- NOWA KLAWIATURA DLA APLIKACJI ---

struct AppKeypadView: View {
    var onTap: (String) -> Void
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...9, id: \.self) { num in
                KeypadButton(text: "\(num)", action: {
                    triggerHaptic()
                    onTap("\(num)")
                })
            }
            
            KeypadButton(text: ".", action: {
                triggerHaptic()
                onTap(".")
            })
            
            KeypadButton(text: "0", action: {
                triggerHaptic()
                onTap("0")
            })
            
            Button(action: {
                triggerHaptic()
                onTap("del")
            }) {
                Image(systemName: "delete.left.fill")
                    .font(.title2)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                    .foregroundColor(.white)
            }
        }
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct KeypadButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.title2.weight(.semibold))
                .frame(height: 55)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.15))
                .cornerRadius(15)
                .foregroundColor(.white)
        }
    }
}

// --- POMOCNICZE WIDOKI ---

struct CurrencyPill: View {
    @Binding var currency: String
    let all: [String]
    
    var body: some View {
        Menu {
            ForEach(all, id: \.self) { curr in
                Button(curr) { currency = curr }
            }
        } label: {
            HStack {
                Text(currency)
                    .font(.headline)
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.2))
            .cornerRadius(20)
        }
    }
}

struct SuccessOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                    .background(Circle().fill(Color.white).padding(2))
                Text("Zapisano!")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
        .transition(.opacity.animation(.easeInOut))
    }
}

// Extension dla zaokrąglania wybranych rogów
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// --- ZAKŁADKA 2: LISTA WYDATKÓW (Z PODSUMOWANIEM) ---

struct ExpensesView: View {
    @EnvironmentObject var manager: ExpenseManager
    @State private var itemToDelete: IndexSet?
    @State private var showDeleteConfirmation = false
    @State private var editingItem: ExpenseItem?
    
    // Grupowanie wydatków po dacie (bez czasu)
    var groupedExpenses: [(Date, [ExpenseItem])] {
        let grouped = Dictionary(grouping: manager.expenses) { item -> Date in
            Calendar.current.startOfDay(for: item.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if manager.expenses.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(groupedExpenses, id: \.0) { date, items in
                            Section(header: DailySummaryHeader(date: date, items: items)) {
                                ForEach(items) { item in
                                    ExpenseRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingItem = item }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                if let index = manager.expenses.firstIndex(of: item) {
                                                    // Usuwanie musi odbywać się na głównej liście w managerze
                                                    manager.delete(at: IndexSet(integer: index))
                                                }
                                            } label: { Label("Usuń", systemImage: "trash") }
                                        }
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
        }
    }
}

// --- NAGŁÓWEK PODSUMOWANIA DNIA ---

struct DailySummaryHeader: View {
    let date: Date
    let items: [ExpenseItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Data
            Text(date.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .foregroundColor(.primary)
                .textCase(nil) // Wyłącza domyślne wielkie litery w sekcjach
            
            // Główna suma w walucie docelowej (zakładamy, że targetCurrency jest zazwyczaj ten sam, np. PLN)
            // Jeśli są różne, sumujemy je osobno, ale dla uproszczenia pokażmy sumę convertedAmount
            // Zakładamy tutaj, że użytkownik głównie przelicza na jedną walutę domową (np. PLN).
            // Jeśli waluty docelowe są różne, wyświetlimy je po przecinku.
            
            let targetTotals = Dictionary(grouping: items, by: { $0.targetCurrency })
                .map { (currency, items) -> String in
                    let sum = items.reduce(0) { $0 + $1.convertedAmount }
                    return "\(formatAmount(sum)) \(currency)"
                }
                .joined(separator: ", ")
            
            Text("Łącznie: \(targetTotals)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.green)
                .textCase(nil)
            
            // Sumy w walutach oryginalnych (np. THB, USD)
            let originalTotals = Dictionary(grouping: items, by: { $0.currency })
                .map { (currency, items) -> String in
                    let sum = items.reduce(0) { $0 + $1.amount }
                    return "\(formatAmount(sum)) \(currency)"
                }
                .joined(separator: " + ")
            
            Text("Wydano: \(originalTotals)")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(nil)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("Brak wydatków").font(.title3.weight(.medium)).foregroundColor(.secondary)
            Text("Twoje zapisane wydatki pojawią się tutaj.").font(.caption).foregroundColor(.secondary)
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
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.amount, format: .currency(code: item.currency))
                    .font(.body.monospacedDigit()).foregroundColor(.secondary)
                Text(item.convertedAmount, format: .currency(code: item.targetCurrency))
                    .font(.title3.weight(.bold)).foregroundColor(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

// --- EDYCJA (ZACHOWANA) ---

struct EditExpenseView: View {
    @State var item: ExpenseItem
    var onSave: (ExpenseItem) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var currentAmountString: String
    @State private var isLoadingRate: Bool = false
    
    init(item: ExpenseItem, onSave: @escaping (ExpenseItem) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
        self._currentAmountString = State(initialValue: String(format: "%.2f", item.amount))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Szczegóły")) {
                    TextField("Opis", text: Binding(get: { item.note ?? "" }, set: { item.note = $0 }))
                    DatePicker("Data", selection: $item.date)
                }
                Section(header: Text("Kwoty i Waluty")) {
                    TextField("0.00", text: $currentAmountString)
                        .keyboardType(.decimalPad)
                        .onChange(of: currentAmountString) { _, newValue in
                            if let val = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                item.amount = val
                                Task { await fetchRate() }
                            }
                        }
                    Picker("Z", selection: $item.currency) {
                        ForEach(ExpenseManager.allCurrencies, id: \.self) { Text($0).tag($0) }
                    }.onChange(of: item.currency) { _,_ in Task { await fetchRate() } }
                    
                    Picker("Na", selection: $item.targetCurrency) {
                        ForEach(ExpenseManager.allCurrencies, id: \.self) { Text($0).tag($0) }
                    }.onChange(of: item.targetCurrency) { _,_ in Task { await fetchRate() } }
                    
                    HStack {
                        Text("Wynik")
                        Spacer()
                        if isLoadingRate { ProgressView() } else {
                            Text("\(item.convertedAmount, format: .number) \(item.targetCurrency)").bold()
                        }
                    }
                }
            }
            .navigationTitle("Edycja")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        if let val = Double(currentAmountString.replacingOccurrences(of: ",", with: ".")) { item.amount = val }
                        onSave(item)
                    }
                }
            }
            .task { await fetchRate() }
        }
    }
    
    func fetchRate() async {
        isLoadingRate = true
        let rate = await ExpenseManager.fetchExchangeRate(from: item.currency, to: item.targetCurrency)
        item.convertedAmount = item.amount * rate
        isLoadingRate = false
    }
}

func formatAmount(_ val: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: val)) ?? "0"
}