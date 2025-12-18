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
    
    // Klucze dla budżetu
    let budgetTotalKey = "tripBudgetTotal"
    let budgetCurrencyKey = "tripBudgetCurrency"
    let secondaryBudgetCurrencyKey = "secondaryBudgetCurrency"
    let budgetStartKey = "tripStartDate"
    let budgetEndKey = "tripEndDate"
    
    @Published var expenses: [ExpenseItem] = []
    
    // Dane budżetu
    @Published var totalBudget: Double = 0.0
    @Published var budgetCurrency: String = "PLN"
    @Published var secondaryBudgetCurrency: String = "THB"
    @Published var tripStartDate: Date = Date()
    @Published var tripEndDate: Date = Date().addingTimeInterval(86400 * 7)
    @Published var isBudgetSet: Bool = false
    
    static let allCurrencies = ["THB", "PLN", "USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD", "CZK", "NOK", "SEK", "HUF", "DKK"]
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }
    
    init() {
        loadExpenses()
        loadBudget()
    }
    
    // --- WYDATKI ---
    
    func loadExpenses() {
        if let data = defaults.data(forKey: expensesKey),
           let items = try? JSONDecoder().decode([ExpenseItem].self, from: data) {
            self.expenses = items.sorted(by: { $0.date > $1.date })
        }
    }
    
    func addExpense(_ expense: ExpenseItem) {
        expenses.append(expense)
        expenses.sort(by: { $0.date > $1.date })
        saveExpenses()
    }
    
    func update(expense: ExpenseItem) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            expenses.sort(by: { $0.date > $1.date })
            saveExpenses()
        }
    }
    
    func delete(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
        saveExpenses()
    }
    
    private func saveExpenses() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            defaults.set(encoded, forKey: expensesKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // --- BUDŻET ---
    
    func loadBudget() {
        self.totalBudget = defaults.double(forKey: budgetTotalKey)
        self.budgetCurrency = defaults.string(forKey: budgetCurrencyKey) ?? "PLN"
        self.secondaryBudgetCurrency = defaults.string(forKey: secondaryBudgetCurrencyKey) ?? "THB"
        self.tripStartDate = defaults.object(forKey: budgetStartKey) as? Date ?? Date()
        self.tripEndDate = defaults.object(forKey: budgetEndKey) as? Date ?? Date().addingTimeInterval(86400 * 7)
        
        self.isBudgetSet = self.totalBudget > 0
    }
    
    func saveBudget(total: Double, currency: String, secondaryCurrency: String, start: Date, end: Date) {
        self.totalBudget = total
        self.budgetCurrency = currency
        self.secondaryBudgetCurrency = secondaryCurrency
        self.tripStartDate = start
        self.tripEndDate = end
        self.isBudgetSet = true
        
        defaults.set(total, forKey: budgetTotalKey)
        defaults.set(currency, forKey: budgetCurrencyKey)
        defaults.set(secondaryCurrency, forKey: secondaryBudgetCurrencyKey)
        defaults.set(start, forKey: budgetStartKey)
        defaults.set(end, forKey: budgetEndKey)
    }
    
    func clearBudget() {
        self.totalBudget = 0
        self.isBudgetSet = false
        defaults.set(0, forKey: budgetTotalKey)
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

struct ExchangeRateResponse: Codable {
    let date: String
    let rates: [String: Double]
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
            
            BudgetView()
                .environmentObject(expenseManager)
                .tabItem {
                    Label("Budżet", systemImage: "chart.pie.fill")
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
    @EnvironmentObject var expenseManager: ExpenseManager
    @State private var showSaveConfirmation: Bool = false
    @State private var note: String = ""
    @State private var inputString: String = "0"

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Konwerter Walut")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 10)
                        
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
                        
                        TextField("Dodaj opis (np. Taxi)", text: $note)
                            .padding(12)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .accentColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .padding(.horizontal, 30)
                            .placeholder(when: note.isEmpty) {
                                Text("Dodaj opis (np. Taxi)").foregroundColor(.white.opacity(0.5)).padding(.leading, 42)
                            }

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
                        
                        Divider().background(Color.white.opacity(0.3)).padding(.horizontal, 30).padding(.vertical, 10)
                        
                        AppKeypadView(onTap: handleKeypadInput)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 20)
                    }
                }
                .scrollIndicators(.hidden)
            }
            
            if showSaveConfirmation {
                SuccessOverlayView()
            }
        }
        .onChange(of: viewModel.fromCurrency) { _,_ in Task { await viewModel.fetchExchangeRate() } }
        .onChange(of: viewModel.toCurrency) { _,_ in Task { await viewModel.fetchExchangeRate() } }
    }
    
    func handleKeypadInput(_ key: String) {
        if key == "del" {
            if inputString.count > 1 { inputString.removeLast() } else { inputString = "0" }
        } else if key == "." {
            if !inputString.contains(".") { inputString += "." }
        } else {
            if inputString == "0" { inputString = key } else if inputString.count < 9 { inputString += key }
        }
        
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
        
        note = ""
        inputString = "0"
        viewModel.amount = 0
        viewModel.calculateResult()
        
        showSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSaveConfirmation = false }
    }
}

// --- ZAKŁADKA 2 (BUDŻET) ---

struct BudgetView: View {
    @EnvironmentObject var manager: ExpenseManager
    @State private var showSetupSheet = false
    @State private var convertedSecondaryTotal: Double = 0.0
    @State private var secondaryRate: Double = 0.0
    @State private var isFetchingRate: Bool = false
    
    var stats: BudgetStats {
        calculateBudgetStats()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if !manager.isBudgetSet {
                    VStack(spacing: 20) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        Text("Zaplanuj Budżet")
                            .font(.title2.weight(.bold))
                        Text("Ustaw budżet na cały wyjazd, a my podzielimy go na dni i będziemy śledzić Twoje wydatki.")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                        
                        Button("Ustaw Budżet") { showSetupSheet = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 1. KARTA DZISIEJSZA (Główna) - TERAZ Z PARAMETRAMI
                            TodayBudgetCard(
                                stats: stats,
                                currency: manager.budgetCurrency,
                                secondaryCurrency: manager.secondaryBudgetCurrency,
                                secondaryRate: secondaryRate,
                                isFetching: isFetchingRate
                            )
                            
                            // 2. HISTORIA DZIENNA (Slider)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Historia Wydatków")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ScrollViewReader { scrollProxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(stats.dailyHistory, id: \.date) { dayStat in
                                                DailyHistoryCard(stat: dayStat, currency: manager.budgetCurrency, dailyBase: stats.dailyBase)
                                                    .id(dayStat.date)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .onAppear {
                                            // Automatyczne przewijanie do ostatniego (najnowszego) dnia
                                            if let lastDay = stats.dailyHistory.last {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    withAnimation {
                                                        scrollProxy.scrollTo(lastDay.date, anchor: .trailing)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 3. OGÓLNE PODSUMOWANIE
                            TripSummaryCard(
                                stats: stats,
                                currency: manager.budgetCurrency,
                                start: manager.tripStartDate,
                                end: manager.tripEndDate,
                                secondaryCurrency: manager.secondaryBudgetCurrency,
                                secondaryRate: secondaryRate,
                                isFetching: isFetchingRate
                            )
                            
                            // PRZYCISK EDYCJI
                            Button("Edytuj ustawienia wyjazdu") { showSetupSheet = true }
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Twój Budżet")
            .sheet(isPresented: $showSetupSheet) {
                BudgetSetupView(isPresented: $showSetupSheet)
            }
            .task(id: manager.budgetCurrency + manager.secondaryBudgetCurrency) {
                await fetchSecondaryRate()
            }
        }
    }
    
    private func fetchSecondaryRate() async {
        isFetchingRate = true
        secondaryRate = await ExpenseManager.fetchExchangeRate(from: manager.budgetCurrency, to: manager.secondaryBudgetCurrency)
        isFetchingRate = false
    }
    
    struct DailyHistoryItem: Identifiable {
        let id = UUID()
        let date: Date
        let dayNum: Int
        let spent: Double
        let spentOriginalCurrencies: [String: Double]
    }
    
    struct BudgetStats {
        let totalDays: Int
        let currentDayNum: Int
        let dailyBase: Double
        
        let spentBeforeToday: Double
        let spentToday: Double
        
        let shouldHaveSpentUntilYesterday: Double
        let savedFromPreviousDays: Double
        
        let availableToday: Double
        let remainingToday: Double
        
        let totalSpent: Double
        let totalRemaining: Double
        let progress: Double
        
        let dailyHistory: [DailyHistoryItem]
    }
    
    func calculateBudgetStats() -> BudgetStats {
        let calendar = Calendar.current
        
        let start = calendar.startOfDay(for: manager.tripStartDate)
        let end = calendar.startOfDay(for: manager.tripEndDate)
        let components = calendar.dateComponents([.day], from: start, to: end)
        let totalDays = max(1, (components.day ?? 0) + 1)
        
        let today = calendar.startOfDay(for: Date())
        let daysFromStart = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let currentDayNum = min(totalDays, max(1, daysFromStart + 1))
        
        let dailyBase = manager.totalBudget / Double(totalDays)
        
        let tripExpenses = manager.expenses.filter { item in
            let itemDate = calendar.startOfDay(for: item.date)
            return itemDate >= start && itemDate <= end
        }
        
        var history: [DailyHistoryItem] = []
        let endDateForHistory = calendar.date(byAdding: .day, value: daysFromStart, to: start) ?? today
        
        var currentDate = start
        var dayCounter = 1
        while currentDate <= endDateForHistory && currentDate <= end {
            let dayExpenses = tripExpenses
                .filter { calendar.isDate($0.date, inSameDayAs: currentDate) }
            
            // POPRAWKA: reduce(0.0)
            let daySpent = dayExpenses.reduce(0.0) { $0 + $1.convertedAmount }
            
            var spentOriginals: [String: Double] = [:]
            for expense in dayExpenses {
                spentOriginals[expense.currency, default: 0.0] += expense.amount
            }
            
            history.append(DailyHistoryItem(date: currentDate, dayNum: dayCounter, spent: daySpent, spentOriginalCurrencies: spentOriginals))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            dayCounter += 1
        }
        
        let spentToday: Double
        if today >= start && today <= end {
            // POPRAWKA: reduce(0.0)
            spentToday = tripExpenses
                .filter { calendar.isDate($0.date, inSameDayAs: today) }
                .reduce(0.0) { $0 + $1.convertedAmount }
        } else {
            spentToday = 0
        }
            
        // POPRAWKA: reduce(0.0)
        let spentBeforeToday = tripExpenses
            .filter { calendar.startOfDay(for: $0.date) < today }
            .reduce(0.0) { $0 + $1.convertedAmount }
            
        // POPRAWKA: reduce(0.0)
        let totalSpent = tripExpenses.reduce(0.0) { $0 + $1.convertedAmount }
        let totalRemaining = manager.totalBudget - totalSpent
        
        let passedBudgetDays = min(totalDays, max(0, daysFromStart))
        let shouldHaveSpentUntilYesterday = dailyBase * Double(passedBudgetDays)
        let savedFromPreviousDays = shouldHaveSpentUntilYesterday - spentBeforeToday
        
        var availableToday = dailyBase + savedFromPreviousDays
        if today < start || today > end {
            availableToday = 0
        }
        
        let remainingToday = availableToday - spentToday
        let progress = availableToday > 0 ? (spentToday / availableToday) : (spentToday > 0 ? 1.0 : 0.0)
        
        return BudgetStats(
            totalDays: totalDays,
            currentDayNum: currentDayNum,
            dailyBase: dailyBase,
            spentBeforeToday: spentBeforeToday,
            spentToday: spentToday,
            shouldHaveSpentUntilYesterday: shouldHaveSpentUntilYesterday,
            savedFromPreviousDays: savedFromPreviousDays,
            availableToday: availableToday,
            remainingToday: remainingToday,
            totalSpent: totalSpent,
            totalRemaining: totalRemaining,
            progress: min(1.0, max(0.0, progress)),
            dailyHistory: history
        )
    }
}

// Karty Widoku Budżetu

struct TodayBudgetCard: View {
    let stats: BudgetView.BudgetStats
    let currency: String
    let secondaryCurrency: String
    let secondaryRate: Double
    let isFetching: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("DZISIAJ (Dzień \(stats.currentDayNum)/\(stats.totalDays))")
                        .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    Text("Dostępne na dziś")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(stats.availableToday, format: .currency(code: currency))
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    
                    if isFetching {
                        ProgressView().scaleEffect(0.8)
                    } else if currency != secondaryCurrency {
                        let availableTodayConverted = stats.availableToday * secondaryRate
                        Text("≈ \(availableTodayConverted, format: .currency(code: secondaryCurrency))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Kołowy wykres
            ZStack {
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.1)
                    .foregroundColor(.secondary)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(stats.progress))
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundColor(getBarColor(progress: stats.progress))
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: stats.progress)
                
                VStack {
                    Text("Zostało")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(stats.remainingToday, format: .currency(code: currency))
                        .font(.title.weight(.bold))
                        .foregroundColor(stats.remainingToday >= 0 ? .primary : .red)
                    
                    if isFetching {
                        ProgressView().scaleEffect(0.8)
                    } else if currency != secondaryCurrency {
                        let remainingTodayConverted = stats.remainingToday * secondaryRate
                        Text("≈ \(remainingTodayConverted, format: .currency(code: secondaryCurrency))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 200)
            .padding(.vertical, 10)
            
            // Legenda
            HStack(spacing: 30) {
                VStack {
                    Text("Wydano")
                        .font(.caption).foregroundColor(.secondary)
                    Text(stats.spentToday, format: .currency(code: currency))
                        .fontWeight(.semibold)
                        .foregroundColor(.red.opacity(0.8))
                }
                
                Divider().frame(height: 30)
                
                VStack {
                    Text(stats.savedFromPreviousDays >= 0 ? "Z przeniesienia" : "Nadwyżka z wczoraj")
                        .font(.caption).foregroundColor(.secondary)
                    Text(stats.savedFromPreviousDays, format: .currency(code: currency))
                        .fontWeight(.semibold)
                        .foregroundColor(stats.savedFromPreviousDays >= 0 ? .green : .red)
                }
            }
        }
        .padding(25)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    func getBarColor(progress: Double) -> Color {
        if progress < 0.5 { return .green }
        if progress < 0.85 { return .orange }
        return .red
    }
}

struct TripSummaryCard: View {
    let stats: BudgetView.BudgetStats
    let currency: String
    let start: Date
    let end: Date
    let secondaryCurrency: String
    let secondaryRate: Double
    let isFetching: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Podsumowanie Wyjazdu")
                .font(.headline)
            
            // Główny budżet
            HStack {
                VStack(alignment: .leading) {
                    Text("Całkowity budżet")
                        .font(.caption).foregroundColor(.secondary)
                    Text((stats.totalSpent + stats.totalRemaining), format: .currency(code: currency))
                        .font(.title3.weight(.bold))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Pozostało w sumie")
                        .font(.caption).foregroundColor(.secondary)
                    Text(stats.totalRemaining, format: .currency(code: currency))
                        .font(.title3.weight(.bold))
                        .foregroundColor(.green)
                }
            }
            
            // Sekcja przeliczenia na walutę lokalną
            if currency != secondaryCurrency {
                Divider().padding(.vertical, 5)
                HStack {
                    VStack(alignment: .leading) {
                        Text("W walucie lokalnej (\(secondaryCurrency))")
                            .font(.caption).foregroundColor(.secondary)
                        
                        if isFetching {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            let totalConverted = (stats.totalSpent + stats.totalRemaining) * secondaryRate
                            Text(totalConverted, format: .currency(code: secondaryCurrency))
                                .font(.headline)
                                .foregroundColor(.primary.opacity(0.8))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Pozostało")
                            .font(.caption).foregroundColor(.secondary)
                        
                        if isFetching {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            let remainingConverted = stats.totalRemaining * secondaryRate
                            Text(remainingConverted, format: .currency(code: secondaryCurrency))
                                .font(.headline)
                                .foregroundColor(.green.opacity(0.8))
                        }
                    }
                }
            }
            
            ProgressView(value: stats.totalSpent, total: stats.totalSpent + stats.totalRemaining)
                .tint(.purple)
                .padding(.top, 5)
            
            HStack {
                Text(start.formatted(date: .numeric, time: .omitted))
                Spacer()
                Text(end.formatted(date: .numeric, time: .omitted))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
}

struct DailyHistoryCard: View {
    let stat: BudgetView.DailyHistoryItem
    let currency: String
    let dailyBase: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dzień \(stat.dayNum)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            Text(stat.date.formatted(.dateTime.day().month()))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(stat.spent, format: .currency(code: currency))
                .font(.headline)
                .foregroundColor(stat.spent > dailyBase ? .red : .primary)
            
            if !stat.spentOriginalCurrencies.isEmpty {
                let originalAmounts = stat.spentOriginalCurrencies.map { curr, amount in
                    "\(formatAmount(amount)) \(curr)"
                }.joined(separator: " + ")
                Text("Wydano: \(originalAmounts)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
            
            if stat.spent > dailyBase {
                Text("Nadwyżka")
                    .font(.caption2)
                    .foregroundColor(.red)
            } else {
                Text("W normie")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .frame(width: 130, height: 130) // Zwiększony rozmiar
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(stat.spent > dailyBase ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct BudgetSetupView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var manager: ExpenseManager
    
    @State private var total: Double = 3000
    @State private var currency: String = "PLN"
    @State private var secondaryCurrency: String = "THB"
    @State private var start: Date = Date()
    @State private var end: Date = Date().addingTimeInterval(86400 * 7)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Finanse")) {
                    TextField("Kwota budżetu", value: $total, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Waluta główna", selection: $currency) {
                        ForEach(ExpenseManager.allCurrencies, id: \.self) { Text($0) }
                    }
                    Picker("Waluta do przeliczenia", selection: $secondaryCurrency) {
                        ForEach(ExpenseManager.allCurrencies, id: \.self) { Text($0) }
                    }
                }
                
                Section(header: Text("Termin")) {
                    DatePicker("Początek", selection: $start, displayedComponents: .date)
                    DatePicker("Koniec", selection: $end, in: start..., displayedComponents: .date)
                }
            }
            .navigationTitle("Ustawienia Budżetu")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        manager.saveBudget(total: total, currency: currency, secondaryCurrency: secondaryCurrency, start: start, end: end)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { isPresented = false }
                }
            }
            .onAppear {
                if manager.isBudgetSet {
                    total = manager.totalBudget
                    currency = manager.budgetCurrency
                    secondaryCurrency = manager.secondaryBudgetCurrency
                    start = manager.tripStartDate
                    end = manager.tripEndDate
                }
            }
        }
    }
}

// --- ZAKŁADKA 3: LISTA WYDATKÓW ---

struct ExpensesView: View {
    @EnvironmentObject var manager: ExpenseManager
    @State private var itemToDelete: IndexSet?
    @State private var showDeleteConfirmation = false
    @State private var editingItem: ExpenseItem?
    
    @State private var summaryCurrency: String = "PLN"
    
    var groupedExpenses: [(Date, [ExpenseItem])] {
        let grouped = Dictionary(grouping: manager.expenses) { item -> Date in
            Calendar.current.startOfDay(for: item.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var availableCurrencies: [String] {
        let sourceCurrencies = Set(manager.expenses.map { $0.currency })
        let targetCurrencies = Set(manager.expenses.map { $0.targetCurrency })
        return Array(sourceCurrencies.union(targetCurrencies)).sorted()
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
                            Section(header: DailySummaryHeader(date: date, items: items, displayCurrency: summaryCurrency)) {
                                ForEach(items) { item in
                                    ExpenseRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingItem = item }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                if let index = manager.expenses.firstIndex(of: item) {
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Text("Pokaż sumy w:")
                        ForEach(availableCurrencies, id: \.self) { currency in
                            Button(action: { summaryCurrency = currency }) {
                                HStack {
                                    Text(currency)
                                    if summaryCurrency == currency {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        if availableCurrencies.isEmpty {
                            Button("PLN") { summaryCurrency = "PLN" }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(summaryCurrency)
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(15)
                    }
                }
            }
            .sheet(item: $editingItem) { item in
                EditExpenseView(item: item) { updatedItem in
                    manager.update(expense: updatedItem)
                    editingItem = nil
                }
            }
        }
    }
}

struct DailySummaryHeader: View {
    let date: Date
    let items: [ExpenseItem]
    let displayCurrency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date.formatted(date: .complete, time: .omitted))
                .font(.headline).foregroundColor(.primary).textCase(nil)
            
            // POPRAWKA: reduce(0.0)
            let totalInSelected = items.reduce(0.0) { sum, item in
                if item.currency == displayCurrency {
                    return sum + item.amount
                } else if item.targetCurrency == displayCurrency {
                    return sum + item.convertedAmount
                }
                return sum
            }
            
            HStack {
                Text("Łącznie:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(formatAmount(totalInSelected)) \(displayCurrency)")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            .textCase(nil)
            
            let otherCurrencies = Dictionary(grouping: items.filter { $0.currency != displayCurrency && $0.targetCurrency != displayCurrency }, by: { $0.currency })
            if !otherCurrencies.isEmpty {
                let others = otherCurrencies.map { (curr, its) -> String in
                    // POPRAWKA: reduce(0.0)
                    let s = its.reduce(0.0) { $0 + $1.amount }
                    return "\(formatAmount(s)) \(curr)"
                }.joined(separator: " + ")
                 Text("(+ inne: \(others))").font(.caption).foregroundColor(.secondary).textCase(nil)
            }
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

// --- EDYCJA ---

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

// --- KLAWIATURA I WSPÓLNE KOMPONENTY ---

struct AppKeypadView: View {
    var onTap: (String) -> Void
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...9, id: \.self) { num in
                KeypadButton(text: "\(num)", action: { triggerHaptic(); onTap("\(num)") })
            }
            KeypadButton(text: ".", action: { triggerHaptic(); onTap(".") })
            KeypadButton(text: "0", action: { triggerHaptic(); onTap("0") })
            Button(action: { triggerHaptic(); onTap("del") }) {
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
}

struct KeypadButton: View {
    let text: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.title2.weight(.semibold))
                .frame(height: 55).frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.15))
                .cornerRadius(15).foregroundColor(.white)
        }
    }
}

struct CurrencyPill: View {
    @Binding var currency: String
    let all: [String]
    var body: some View {
        Menu {
            ForEach(all, id: \.self) { curr in Button(curr) { currency = curr } }
        } label: {
            HStack { Text(currency).font(.headline).foregroundColor(.white); Image(systemName: "chevron.down").font(.caption).foregroundColor(.white.opacity(0.7)) }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white.opacity(0.2)).cornerRadius(20)
        }
    }
}

struct SuccessOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundColor(.green).background(Circle().fill(Color.white).padding(2))
                Text("Zapisano!").font(.title3.weight(.bold)).foregroundColor(.white)
            }
            .padding(30).background(.ultraThinMaterial).cornerRadius(20)
        }
        .transition(.opacity.animation(.easeInOut))
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
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.prepare()
    generator.impactOccurred()
}

// Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View { clipShape(RoundedCorner(radius: radius, corners: corners)) }
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) { placeholder().opacity(shouldShow ? 1 : 0); self }
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}