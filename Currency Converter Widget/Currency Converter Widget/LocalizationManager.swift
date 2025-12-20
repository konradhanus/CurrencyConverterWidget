import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    enum Language: String, CaseIterable, Identifiable {
        case system = "System"
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
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .system: return "System"
            case .english: return "English"
            case .polish: return "Polski"
            case .german: return "Deutsch"
            case .dutch: return "Nederlands"
            case .spanish: return "Español"
            case .french: return "Français"
            case .chinese: return "中文"
            case .japanese: return "日本語"
            case .portuguese: return "Português"
            case .czech: return "Čeština"
            case .slovak: return "Slovenčina"
            case .croatian: return "Hrvatski"
            case .russian: return "Русский"
            case .serbian: return "Српски"
            case .ukrainian: return "Українська"
            case .thai: return "ไทย"
            case .hindi: return "हिन्दी"
            case .greek: return "Ελληνικά"
            case .italian: return "Italiano"
            case .arabic: return "العربية"
            case .hungarian: return "Magyar"
            case .finnish: return "Suomi"
            case .icelandic: return "Íslenska"
            case .norwegian: return "Norsk"
            case .swedish: return "Svenska"
            case .romanian: return "Română"
            case .mongolian: return "Монгол"
            }
        }
    }
    
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = "System"
    
    @Published var currentLanguage: Language = .system {
        didSet {
            if currentLanguage.rawValue != selectedLanguageRaw {
                selectedLanguageRaw = currentLanguage.rawValue
            }
            loadLanguage()
        }
    }
    
    @Published private var translations: [String: String] = [:]
    
    var appLocale: Locale {
        if currentLanguage == .system {
            return Locale.current
        } else {
            return Locale(identifier: currentLanguage.rawValue)
        }
    }
    
    init() {
        if let saved = Language(rawValue: selectedLanguageRaw) {
            currentLanguage = saved
        }
        loadLanguage()
    }
    
    func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = translations[key] ?? key
        if args.isEmpty { return format }
        return String(format: format, arguments: args)
    }
    
    // Helper for SwiftUI Text
    func text(_ key: String, _ args: CVarArg...) -> Text {
        Text(localized(key, args))
    }
    
    private func loadLanguage() {
        let langCodeToLoad: String
        let valueKey: String
        
        if currentLanguage == .system {
            let sys = Locale.current.language.languageCode?.identifier ?? "en"
            // If system is PL, load PL. Otherwise load EN.
            if sys == "pl" {
                langCodeToLoad = "pl"
                valueKey = "pl"
            } else {
                langCodeToLoad = "en" // Default to English file
                valueKey = "en"
            }
        } else {
            langCodeToLoad = currentLanguage.rawValue
            valueKey = currentLanguage.rawValue
        }
        
        // Load file: e.g., "pl.json"
        
        // 1. Try finding it in the root (common when adding to target directly)
        var url = Bundle.main.url(forResource: langCodeToLoad, withExtension: "json")
        
        // 2. Try 'Localization' subdirectory
        if url == nil {
            url = Bundle.main.url(forResource: langCodeToLoad, withExtension: "json", subdirectory: "Localization")
        }
        
        // 3. Try 'Resources/Localization' subdirectory (our folder structure)
        if url == nil {
            url = Bundle.main.url(forResource: langCodeToLoad, withExtension: "json", subdirectory: "Resources/Localization")
        }
        
        // 4. Fallback: Search recursively for ANY file with that name in the bundle
        if url == nil {
            // Helper to search recursively if standard paths fail
            if let resourcePath = Bundle.main.resourcePath {
                let fileManager = FileManager.default
                if let enumerator = fileManager.enumerator(atPath: resourcePath) {
                    for case let file as String in enumerator {
                        if file.hasSuffix("\(langCodeToLoad).json") {
                            url = Bundle.main.bundleURL.appendingPathComponent(file)
                            print("LocalizationManager: Found file recursively at \(file)")
                            break
                        }
                    }
                }
            }
        }

        guard let finalUrl = url else {
            print("LocalizationManager CRITICAL ERROR: Could not find language file for '\(langCodeToLoad)' in Bundle path: \(Bundle.main.bundlePath)")
            // List contents of bundle root to help debug
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                 print("Bundle Root Contents: \(contents)")
            }
            return
        }
        
        print("LocalizationManager: Loading language from \(finalUrl.path)")
        
        do {
            let data = try Data(contentsOf: finalUrl)
            // Structure: { "KEY": { "en": "...", "pl": "...", "description": "..." } }
            let json = try JSONDecoder().decode([String: [String: String]].self, from: data)
            var newTrans: [String: String] = [:]
            
            for (key, details) in json {
                if let val = details[valueKey] {
                    newTrans[key] = val
                } else if let val = details["en"] {
                    // Fallback to EN if specific lang missing in that file
                    newTrans[key] = val
                } else {
                    newTrans[key] = key
                }
            }
            
            DispatchQueue.main.async {
                self.translations = newTrans
            }
        } catch {
            print("Error loading language: \(error)")
        }
    }
}
