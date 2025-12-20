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

// Struktura reprezentująca zakończony lub zapisany wyjazd
struct Trip: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var totalBudget: Double
    var budgetCurrency: String
    var secondaryBudgetCurrency: String
    var startDate: Date
    var endDate: Date
    var expenses: [ExpenseItem]
}

class ExpenseManager: ObservableObject {
    static let shared = ExpenseManager()
    let suiteName = "group.com.currencyconverter.shared"
    
    // Klucze UserDefaults
    let expensesKey = "savedExpensesList"
    let budgetTotalKey = "tripBudgetTotal"
    let budgetCurrencyKey = "tripBudgetCurrency"
    let secondaryBudgetCurrencyKey = "secondaryBudgetCurrency"
    let budgetStartKey = "tripStartDate"
    let budgetEndKey = "tripEndDate"
    let tripNameKey = "tripName" // Nowy klucz
    let archivedTripsKey = "archivedTrips" // Nowy klucz dla historii
    
    // DANE AKTYWNEGO WYJAZDU
    @Published var expenses: [ExpenseItem] = []
    @Published var tripName: String = ""
    @Published var totalBudget: Double = 0.0
    @Published var budgetCurrency: String = "PLN"
    @Published var secondaryBudgetCurrency: String = "THB"
    @Published var tripStartDate: Date = Date()
    @Published var tripEndDate: Date = Date().addingTimeInterval(86400 * 7)
    @Published var isBudgetSet: Bool = false
    
    // HISTORIA
    @Published var archivedTrips: [Trip] = []
    
    static let allCurrencies = ["THB", "PLN", "USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD", "CZK", "NOK", "SEK", "HUF", "DKK"]
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }
    
    init() {
        loadActiveTrip()
        loadArchivedTrips()
    }
    
    // --- ZARZĄDZANIE AKTYWNYM WYJAZDEM ---
    
    func loadActiveTrip() {
        if let data = defaults.data(forKey: expensesKey),
           let items = try? JSONDecoder().decode([ExpenseItem].self, from: data) {
            self.expenses = items.sorted(by: { $0.date > $1.date })
        }
        
        self.tripName = defaults.string(forKey: tripNameKey) ?? ""
        self.totalBudget = defaults.double(forKey: budgetTotalKey)
        self.budgetCurrency = defaults.string(forKey: budgetCurrencyKey) ?? "PLN"
        self.secondaryBudgetCurrency = defaults.string(forKey: secondaryBudgetCurrencyKey) ?? "THB"
        self.tripStartDate = defaults.object(forKey: budgetStartKey) as? Date ?? Date()
        self.tripEndDate = defaults.object(forKey: budgetEndKey) as? Date ?? Date().addingTimeInterval(86400 * 7)
        
        self.isBudgetSet = self.totalBudget > 0
    }
    
    func saveActiveTripSettings(name: String, total: Double, currency: String, secondary: String, start: Date, end: Date) {
        self.tripName = name
        self.totalBudget = total
        self.budgetCurrency = currency
        self.secondaryBudgetCurrency = secondary
        self.tripStartDate = start
        self.tripEndDate = end
        self.isBudgetSet = true
        
        defaults.set(name, forKey: tripNameKey)
        defaults.set(total, forKey: budgetTotalKey)
        defaults.set(currency, forKey: budgetCurrencyKey)
        defaults.set(secondary, forKey: secondaryBudgetCurrencyKey)
        defaults.set(start, forKey: budgetStartKey)
        defaults.set(end, forKey: budgetEndKey)
    }
    
    // --- WYDATKI (CRUD) ---
    
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
    
    // --- ARCHIWIZACJA I HISTORIA ---
    
    func loadArchivedTrips() {
        if let data = defaults.data(forKey: archivedTripsKey),
           let trips = try? JSONDecoder().decode([Trip].self, from: data) {
            self.archivedTrips = trips.sorted(by: { $0.startDate > $1.startDate })
        }
    }
    
    // Zakończ obecny wyjazd (przenieś do historii, wyczyść aktywny)
    func finishCurrentTrip() {
        guard isBudgetSet else { return }
        
        let tripToArchive = Trip(
            id: UUID(),
            name: tripName.isEmpty ? "Wyjazd bez nazwy" : tripName,
            totalBudget: totalBudget,
            budgetCurrency: budgetCurrency,
            secondaryBudgetCurrency: secondaryBudgetCurrency,
            startDate: tripStartDate,
            endDate: tripEndDate,
            expenses: expenses
        )
        
        archivedTrips.insert(tripToArchive, at: 0) // Dodaj na początek
        saveArchivedTrips()
        
        // Resetuj aktywny
        clearActiveTrip()
    }
    
    // Przywróć wyjazd z historii do edycji (zamienia się miejscami z obecnym, jeśli obecny nie jest pusty, to go archiwizuje)
    func restoreTripToActive(_ trip: Trip) {
        // Jeśli mamy teraz aktywny wyjazd z danymi, najpierw go zapiszmy!
        if isBudgetSet && !expenses.isEmpty {
            finishCurrentTrip()
        }
        
        // Wczytaj dane z historii do "Active"
        self.tripName = trip.name
        self.totalBudget = trip.totalBudget
        self.budgetCurrency = trip.budgetCurrency
        self.secondaryBudgetCurrency = trip.secondaryBudgetCurrency
        self.tripStartDate = trip.startDate
        self.tripEndDate = trip.endDate
        self.expenses = trip.expenses
        self.isBudgetSet = true
        
        // Zapisz nowy stan "Active"
        saveActiveTripSettings(name: tripName, total: totalBudget, currency: budgetCurrency, secondary: secondaryBudgetCurrency, start: tripStartDate, end: tripEndDate)
        saveExpenses()
        
        // Usuń przywrócony wyjazd z listy archiwalnej (bo teraz jest aktywny)
        if let index = archivedTrips.firstIndex(where: { $0.id == trip.id }) {
            archivedTrips.remove(at: index)
            saveArchivedTrips()
        }
    }
    
    func deleteArchivedTrip(at offsets: IndexSet) {
        archivedTrips.remove(atOffsets: offsets)
        saveArchivedTrips()
    }
    
    private func saveArchivedTrips() {
        if let encoded = try? JSONEncoder().encode(archivedTrips) {
            defaults.set(encoded, forKey: archivedTripsKey)
        }
    }
    
    private func clearActiveTrip() {
        self.tripName = ""
        self.totalBudget = 0
        self.expenses = []
        self.isBudgetSet = false
        self.tripStartDate = Date()
        self.tripEndDate = Date().addingTimeInterval(86400 * 7)
        
        // Czyścimy UserDefaults
        defaults.set("", forKey: tripNameKey)
        defaults.set(0, forKey: budgetTotalKey)
        defaults.removeObject(forKey: expensesKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // --- API ---
    
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
    @EnvironmentObject var loc: LocalizationManager
    
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
                    Label(loc.localized("tab_converter"), systemImage: "arrow.triangle.2.circlepath")
                }
            
            BudgetView()
                .environmentObject(expenseManager)
                .tabItem {
                    Label(loc.localized("tab_budget"), systemImage: "chart.pie.fill")
                }
            
            ExpensesView()
                .environmentObject(expenseManager)
                .tabItem {
                    Label(loc.localized("tab_expenses"), systemImage: "list.bullet.rectangle.portrait")
                }
            
            SettingsView()
                .environmentObject(expenseManager) // Pass just in case, or for uniformity
                .tabItem {
                    Label(loc.localized("tab_settings"), systemImage: "gearshape.fill")
                }
        }
        .environment(\.locale, loc.appLocale)
        .accentColor(.purple)
    }
}

// --- ZAKŁADKA 4: USTAWIENIA ---
struct SettingsView: View {
    @EnvironmentObject var loc: LocalizationManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(loc.localized("language_settings_title"))) {
                    Picker(loc.localized("language_settings_title"), selection: $loc.currentLanguage) {
                        ForEach(LocalizationManager.Language.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .navigationTitle(loc.localized("tab_settings"))
        }
    }
}

// --- ZAKŁADKA 1: KALKULATOR ---

struct CalculatorView: View {
    @StateObject private var viewModel = ExchangeRateViewModel()
    @EnvironmentObject var expenseManager: ExpenseManager
    @EnvironmentObject var loc: LocalizationManager
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
                        Text(loc.localized("app_name"))
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
                        
                        TextField(loc.localized("input_placeholder_desc"), text: $note)
                            .padding(12)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .accentColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .padding(.horizontal, 30)
                            .placeholder(when: note.isEmpty) {
                                Text(loc.localized("input_placeholder_desc")).foregroundColor(.white.opacity(0.5)).padding(.leading, 42)
                            }

                        Button(action: saveExpense) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text(loc.localized("save_expense_button"))
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
    @EnvironmentObject var loc: LocalizationManager
    @State private var showSetupSheet = false
    @State private var showHistorySheet = false // Nowy sheet dla historii
    @State private var showFinishAlert = false // Alert kończenia wyjazdu
    
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
                        Text(loc.localized("budget_setup_empty_title"))
                            .font(.title2.weight(.bold))
                        Text(loc.localized("budget_setup_empty_desc"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                        
                        Button(loc.localized("btn_set_budget")) { showSetupSheet = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                        
                        // Przycisk historii (gdy nie ma aktywnego budżetu)
                        if !manager.archivedTrips.isEmpty {
                            Button(loc.localized("btn_trip_history")) { showHistorySheet = true }
                                .padding(.top, 10)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            
                            // Nazwa wyjazdu (jeśli jest)
                            if !manager.tripName.isEmpty {
                                Text(manager.tripName.uppercased())
                                    .font(.caption).fontWeight(.black)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, -10)
                            }
                            
                            // 1. KARTA DZISIEJSZA
                            TodayBudgetCard(
                                stats: stats,
                                currency: manager.budgetCurrency,
                                secondaryCurrency: manager.secondaryBudgetCurrency,
                                secondaryRate: secondaryRate,
                                isFetching: isFetchingRate
                            )
                            
                            // 2. HISTORIA DZIENNA
                            VStack(alignment: .leading, spacing: 10) {
                                Text(loc.localized("history_expenses_title"))
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
                            
                            // Sekcja zarządzania
                            VStack(spacing: 15) {
                                Button(loc.localized("btn_edit_settings")) { showSetupSheet = true }
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                
                                Button(role: .destructive) {
                                    showFinishAlert = true
                                } label: {
                                    Text(loc.localized("btn_finish_trip"))
                                        .font(.subheadline.weight(.medium))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 20)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.top, 10)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle(loc.localized("budget_screen_title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showHistorySheet = true }) {
                            Label(loc.localized("btn_trip_history"), systemImage: "clock.arrow.circlepath")
                        }
                        
                        if manager.isBudgetSet {
                            Divider()
                            Text(loc.localized("menu_budget_currency"))
                            ForEach(ExpenseManager.allCurrencies, id: \.self) { currency in
                                Button(action: {
                                    manager.saveActiveTripSettings(
                                        name: manager.tripName,
                                        total: manager.totalBudget,
                                        currency: currency,
                                        secondary: manager.secondaryBudgetCurrency,
                                        start: manager.tripStartDate,
                                        end: manager.tripEndDate
                                    )
                                }) {
                                    HStack {
                                        Text(currency)
                                        if manager.budgetCurrency == currency {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showSetupSheet) {
                BudgetSetupView(isPresented: $showSetupSheet)
            }
            .sheet(isPresented: $showHistorySheet) {
                TripsHistoryView()
            }
            .confirmationDialog(loc.localized("alert_finish_title"), isPresented: $showFinishAlert, titleVisibility: .visible) {
                Button(loc.localized("btn_finish_archive"), role: .destructive) {
                    manager.finishCurrentTrip()
                }
                Button(loc.localized("btn_cancel"), role: .cancel) {}
            } message: {
                Text(loc.localized("alert_finish_message"))
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
        let dailyLimit: Double
        let rollover: Double
        
        var availableThatDay: Double { dailyLimit + rollover }
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
        var currentRollover: Double = 0.0
        
        while currentDate <= endDateForHistory && currentDate <= end {
            let dayExpenses = tripExpenses.filter { calendar.isDate($0.date, inSameDayAs: currentDate) }
            let daySpent = dayExpenses.reduce(0.0) { $0 + $1.convertedAmount }
            
            var spentOriginals: [String: Double] = [:]
            for expense in dayExpenses {
                spentOriginals[expense.currency, default: 0.0] += expense.amount
            }
            
            history.append(DailyHistoryItem(
                date: currentDate,
                dayNum: dayCounter,
                spent: daySpent,
                spentOriginalCurrencies: spentOriginals,
                dailyLimit: dailyBase,
                rollover: currentRollover
            ))
            
            let availableTodayInLoop = dailyBase + currentRollover
            currentRollover = availableTodayInLoop - daySpent
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            dayCounter += 1
        }
        
        let spentToday: Double
        if today >= start && today <= end {
            spentToday = tripExpenses
                .filter { calendar.isDate($0.date, inSameDayAs: today) }
                .reduce(0.0) { $0 + $1.convertedAmount }
        } else {
            spentToday = 0
        }
            
        let spentBeforeToday = tripExpenses
            .filter { calendar.startOfDay(for: $0.date) < today }
            .reduce(0.0) { $0 + $1.convertedAmount }
            
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

// Karty Widoku Budżetu (BEZ ZMIAN)
struct TodayBudgetCard: View {
    let stats: BudgetView.BudgetStats
    let currency: String
    let secondaryCurrency: String
    let secondaryRate: Double
    let isFetching: Bool
    @EnvironmentObject var loc: LocalizationManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text(loc.localized("today_header", String(stats.currentDayNum), String(stats.totalDays)))
                        .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    Text(loc.localized("available_today"))
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
            
            ZStack {
                Circle().stroke(lineWidth: 20).opacity(0.1).foregroundColor(.secondary)
                Circle().trim(from: 0.0, to: CGFloat(stats.progress))
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundColor(getBarColor(progress: stats.progress))
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: stats.progress)
                
                VStack {
                    Text(loc.localized("remaining")).font(.caption2).foregroundColor(.secondary)
                    Text(stats.remainingToday, format: .currency(code: currency))
                        .font(.title.weight(.bold)).foregroundColor(stats.remainingToday >= 0 ? .primary : .red)
                    if isFetching { ProgressView().scaleEffect(0.8) }
                    else if currency != secondaryCurrency {
                        let remainingTodayConverted = stats.remainingToday * secondaryRate
                        Text("≈ \(remainingTodayConverted, format: .currency(code: secondaryCurrency))").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 200).padding(.vertical, 10)
            
            HStack(spacing: 30) {
                VStack {
                    Text(loc.localized("spent")).font(.caption).foregroundColor(.secondary)
                    Text(stats.spentToday, format: .currency(code: currency)).fontWeight(.semibold).foregroundColor(.red.opacity(0.8))
                }
                Divider().frame(height: 30)
                VStack {
                    Text(stats.savedFromPreviousDays >= 0 ? loc.localized("rollover_positive") : loc.localized("rollover_negative")).font(.caption).foregroundColor(.secondary)
                    Text(stats.savedFromPreviousDays, format: .currency(code: currency)).fontWeight(.semibold).foregroundColor(stats.savedFromPreviousDays >= 0 ? .green : .red)
                }
            }
        }
        .padding(25).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(25).shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    func getBarColor(progress: Double) -> Color { if progress < 0.5 { return .green }; if progress < 0.85 { return .orange }; return .red }
}

struct TripSummaryCard: View {
    let stats: BudgetView.BudgetStats
    let currency: String
    let start: Date
    let end: Date
    let secondaryCurrency: String
    let secondaryRate: Double
    let isFetching: Bool
    @EnvironmentObject var loc: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(loc.localized("trip_summary_title")).font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(loc.localized("total_budget_label")).font(.caption).foregroundColor(.secondary)
                    Text((stats.totalSpent + stats.totalRemaining), format: .currency(code: currency)).font(.title3.weight(.bold))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(loc.localized("total_remaining_label")).font(.caption).foregroundColor(.secondary)
                    Text(stats.totalRemaining, format: .currency(code: currency)).font(.title3.weight(.bold)).foregroundColor(.green)
                }
            }
            if currency != secondaryCurrency {
                Divider().padding(.vertical, 5)
                HStack {
                    VStack(alignment: .leading) {
                        Text(loc.localized("local_currency_label", secondaryCurrency)).font(.caption).foregroundColor(.secondary)
                        if isFetching { ProgressView().scaleEffect(0.8) } else {
                            Text((stats.totalSpent + stats.totalRemaining) * secondaryRate, format: .currency(code: secondaryCurrency)).font(.headline).foregroundColor(.primary.opacity(0.8))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(loc.localized("remaining_label")).font(.caption).foregroundColor(.secondary)
                        if isFetching { ProgressView().scaleEffect(0.8) } else {
                            Text(stats.totalRemaining * secondaryRate, format: .currency(code: secondaryCurrency)).font(.headline).foregroundColor(.green.opacity(0.8))
                        }
                    }
                }
            }
            ProgressView(value: stats.totalSpent, total: stats.totalSpent + stats.totalRemaining).tint(.purple).padding(.top, 5)
            HStack {
                Text(start.formatted(.dateTime.day().month().year().locale(loc.appLocale)))
                Spacer()
                Text(end.formatted(.dateTime.day().month().year().locale(loc.appLocale)))
            }.font(.caption).foregroundColor(.secondary)
        }
        .padding(20).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(20)
    }
}

struct DailyHistoryCard: View {
    let stat: BudgetView.DailyHistoryItem
    let currency: String
    let dailyBase: Double
    @EnvironmentObject var loc: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(loc.localized("day_label", String(stat.dayNum))).font(.caption2).fontWeight(.bold); Spacer(); Text(stat.date.formatted(.dateTime.day().month().locale(loc.appLocale))).font(.caption2).foregroundColor(.secondary) }
            Divider().padding(.vertical, 2)
            Text("\(loc.localized("spent")):") .font(.caption2).foregroundColor(.secondary)
            Text(stat.spent, format: .currency(code: currency)).font(.subheadline).fontWeight(.bold).foregroundColor(stat.spent > stat.availableThatDay ? .red : .primary)
            HStack(spacing: 2) { Text(loc.localized("limit_label")).font(.caption2).foregroundColor(.secondary); Text(stat.dailyLimit, format: .currency(code: currency)).font(.caption2) }
            if stat.rollover != 0 {
                HStack(spacing: 2) { Image(systemName: stat.rollover > 0 ? "arrow.turn.right.down" : "arrow.turn.right.up").font(.caption2); Text(stat.rollover, format: .currency(code: currency)).font(.caption2).fontWeight(.semibold) }.foregroundColor(stat.rollover > 0 ? .green : .red)
            } else { Text(loc.localized("no_rollover")).font(.caption2).foregroundColor(.secondary).opacity(0.5) }
            Spacer()
            if !stat.spentOriginalCurrencies.isEmpty {
                let originalAmounts = stat.spentOriginalCurrencies.map { "\(formatAmount($1)) \($0)" }.joined(separator: "+")
                Text(originalAmounts).font(.system(size: 8)).foregroundColor(.secondary).lineLimit(1)
            }
        }
        .padding(10).frame(width: 140, height: 140).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(stat.spent > stat.availableThatDay ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1))
    }
}

struct BudgetSetupView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var manager: ExpenseManager
    @EnvironmentObject var loc: LocalizationManager
    
    @State private var name: String = ""
    @State private var total: Double = 3000
    @State private var currency: String = "PLN"
    @State private var secondaryCurrency: String = "THB"
    @State private var start: Date = Date()
    @State private var end: Date = Date().addingTimeInterval(86400 * 7)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(loc.localized("section_info"))) {
                    TextField(loc.localized("trip_name_placeholder"), text: $name)
                }
                
                Section(header: Text(loc.localized("section_finance"))) {
                    TextField(loc.localized("budget_amount_label"), value: $total, format: .number).keyboardType(.decimalPad)
                    Picker(loc.localized("primary_currency_label"), selection: $currency) { ForEach(ExpenseManager.allCurrencies, id: \.self) { Text($0) } }
                    Picker(loc.localized("secondary_currency_label"), selection: $secondaryCurrency) { ForEach(ExpenseManager.allCurrencies, id: \.self) { Text($0) } }
                }
                Section(header: Text(loc.localized("section_term"))) {
                    DatePicker(loc.localized("start_date_label"), selection: $start, displayedComponents: .date)
                    DatePicker(loc.localized("end_date_label"), selection: $end, in: start..., displayedComponents: .date)
                }
                
                Section(header: Text(loc.localized("language_settings_title"))) {
                    Picker(loc.localized("language_settings_title"), selection: $loc.currentLanguage) {
                        ForEach(LocalizationManager.Language.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }
            }
            .navigationTitle(manager.isBudgetSet ? loc.localized("edit_budget_title") : loc.localized("new_budget_title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.localized("btn_save")) {
                        manager.saveActiveTripSettings(name: name, total: total, currency: currency, secondary: secondaryCurrency, start: start, end: end)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button(loc.localized("btn_cancel")) { isPresented = false } }
            }
            .onAppear {
                if manager.isBudgetSet {
                    name = manager.tripName
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

// --- NOWY WIDOK: HISTORIA WYJAZDÓW ---

struct TripsHistoryView: View {
    @EnvironmentObject var manager: ExpenseManager
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(manager.archivedTrips) { trip in
                    TripHistoryRow(trip: trip)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                manager.restoreTripToActive(trip)
                                dismiss()
                            } label: {
                                Label(loc.localized("restore_edit_action"), systemImage: "pencil")
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                if let index = manager.archivedTrips.firstIndex(of: trip) {
                                    manager.deleteArchivedTrip(at: IndexSet(integer: index))
                                }
                            } label: {
                                Label(loc.localized("delete_action"), systemImage: "trash")
                            }
                            
                            Button {
                                manager.restoreTripToActive(trip)
                                dismiss()
                            } label: {
                                Label(loc.localized("restore_action"), systemImage: "arrow.uturn.backward")
                            }
                            .tint(.orange)
                        }
                }
                
                if manager.archivedTrips.isEmpty {
                    Text(loc.localized("no_finished_trips"))
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle(loc.localized("finished_trips_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.localized("btn_close")) { dismiss() }
                }
            }
        }
    }
}

struct TripHistoryRow: View {
    let trip: Trip
    @EnvironmentObject var loc: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(trip.name)
                .font(.headline)
            
            HStack {
                Text(trip.startDate.formatted(.dateTime.day().month().year().locale(loc.appLocale)) + " - " + trip.endDate.formatted(.dateTime.day().month().year().locale(loc.appLocale)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let spent = trip.expenses.reduce(0.0) { $0 + $1.convertedAmount }
                Text(loc.localized("spent_total_label", formatAmount(spent), formatAmount(trip.totalBudget), trip.budgetCurrency))
                    .font(.subheadline)
                    .foregroundColor(spent > trip.totalBudget ? .red : .green)
            }
        }
        .padding(.vertical, 5)
    }
}

// --- ZAKŁADKA 3: LISTA WYDATKÓW ---

struct ExpensesView: View {
    @EnvironmentObject var manager: ExpenseManager
    @EnvironmentObject var loc: LocalizationManager
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
                                            } label: { Label(loc.localized("delete_action"), systemImage: "trash") }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(loc.localized("my_expenses_title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Text(loc.localized("show_totals_in"))
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
    @EnvironmentObject var loc: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date.formatted(.dateTime.day().month().year().weekday(.wide).locale(loc.appLocale)))
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
                Text(loc.localized("total_label"))
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
                 Text(loc.localized("plus_others", others)).font(.caption).foregroundColor(.secondary).textCase(nil)
            }
        }
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var loc: LocalizationManager
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text(loc.localized("no_expenses_title")).font(.title3.weight(.medium)).foregroundColor(.secondary)
            Text(loc.localized("no_expenses_desc")).font(.caption).foregroundColor(.secondary)
        }
    }
}

struct ExpenseRow: View {
    let item: ExpenseItem
    @EnvironmentObject var loc: LocalizationManager
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.note?.isEmpty == false ? item.note! : loc.localized("no_description"))
                    .font(.headline)
                    .foregroundColor(item.note?.isEmpty == false ? .primary : .secondary)
                Text(item.date.formatted(.dateTime.day().month().hour().minute().locale(loc.appLocale)))
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
    @EnvironmentObject var loc: LocalizationManager
    
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
                Section(header: Text(loc.localized("section_details"))) {
                    TextField(loc.localized("label_description"), text: Binding(get: { item.note ?? "" }, set: { item.note = $0 }))
                    DatePicker(loc.localized("label_date"), selection: $item.date)
                }
                Section(header: Text(loc.localized("section_amounts_currencies"))) {
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
                        Text(loc.localized("label_result"))
                        Spacer()
                        if isLoadingRate { ProgressView() } else {
                            Text("\(item.convertedAmount, format: .number) \(item.targetCurrency)").bold()
                        }
                    }
                }
            }
            .navigationTitle(loc.localized("title_edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc.localized("btn_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.localized("btn_save")) {
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
    @EnvironmentObject var loc: LocalizationManager
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundColor(.green).background(Circle().fill(Color.white).padding(2))
                Text(loc.localized("saved_success")).font(.title3.weight(.bold)).foregroundColor(.white)
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