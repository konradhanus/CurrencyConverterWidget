import SwiftUI

// Enum representing the available theme options
enum ColorSchemeOption: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .auto:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

// Manager to handle theme state and persistence in UserDefaults
class ThemeManager: ObservableObject {
    @Published var colorSchemeOption: ColorSchemeOption = .auto {
        didSet {
            saveTheme()
        }
    }
    
    private let themeKey = "selectedAppTheme"
    
    init() {
        loadTheme()
    }
    
    // The actual ColorScheme value to be used by SwiftUI views
    var preferredColorScheme: ColorScheme? {
        switch colorSchemeOption {
        case .auto:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    private func loadTheme() {
        if let storedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = ColorSchemeOption(rawValue: storedTheme) {
            self.colorSchemeOption = theme
        }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(colorSchemeOption.rawValue, forKey: themeKey)
    }
}
