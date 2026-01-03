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
            case .korean: return "한국어"
            case .turkish: return "Türkçe"
            case .danish: return "Dansk"
            case .hebrew: return "עברית"
            case .indonesian: return "Bahasa Indonesia"
            case .vietnamese: return "Tiếng Việt"
            case .malay: return "Bahasa Melayu"
            case .filipino: return "Filipino"
            case .bulgarian: return "Български"
            case .lithuanian: return "Lietuvių"
            case .latvian: return "Latviešu"
            case .estonian: return "Eesti"
            case .slovenian: return "Slovenščina"
            case .catalan: return "Català"
            case .swahili: return "Kiswahili"
            case .georgian: return "ქართული"
            case .albanian: return "Shqip"
            case .macedonian: return "Македонски"
            case .afrikaans: return "Afrikaans"
            case .khmer: return "ភាសាខ្មែរ"
            case .persian: return "فارسی"
            case .urdu: return "اردو"
            case .bengali: return "বাংলা"
            case .punjabi: return "ਪੰਜਾਬੀ"
            case .tamil: return "தமிழ்"
            case .telugu: return "తెలుగు"
            case .marathi: return "मराठी"
            case .gujarati: return "ગુજરાતી"
            case .kannada: return "ಕನ್ನಡ"
            case .malayalam: return "മലയാളം"
            case .sinhala: return "සිംහල"
            case .burmese: return "မြန်မာ"
            case .lao: return "ລາវ"
            case .nepali: return "नेपाली"
            case .armenian: return "ჰայերენ"
            case .azerbaijani: return "Azərbaycan"
            case .kazakh: return "Қазақша"
            case .uzbek: return "Oʻzbek"
            case .turkmen: return "Türkmen"
            case .kyrgyz: return "Кыргызча"
            case .tajik: return "Тоҷикӣ"
            case .pashto: return "پښتو"
            case .kurdish: return "Kurdî"
            case .amharic: return "ამჰარული"
            case .somali: return "Soomaali"
            case .yoruba: return "Yorùbá"
            case .igbo: return "Igbo"
            case .hausa: return "Hausa"
            case .zulu: return "isiZulu"
            case .xhosa: return "isiXhosa"
            case .bosnian: return "Bosanski"
            case .maltese: return "Malti"
            case .irish: return "Gaeilge"
            case .welsh: return "Cymraeg"
            case .basque: return "Euskara"
            case .galician: return "Galego"
            case .belarusian: return "Беларуская"
            case .luxembourgish: return "Lëtzebuergesch"
            case .haitian: return "Kreyòl Ayisyen"
            case .javanese: return "Jawa"
            case .kinyarwanda: return "Kinyarwanda"
            case .malagasy: return "Malagasy"
            case .shona: return "ChiShona"
            case .sindhi: return "سنڌي"
            case .uyghur: return "ئۇيغۇرچە"
            case .tatar: return "Татарча"
            case .odia: return "ଓଡ଼ିଆ"
            case .assamese: return "অসমীয়া"
            case .tigrinya: return "ትግርኛ"
            case .quechua: return "Runasimi"
            }
        }
    }
    
    @AppStorage("selectedLanguage", store: UserDefaults(suiteName: "group.com.currencyconverter.shared")) private var selectedLanguageRaw: String = "System"
    
    @Published var currentLanguage: Language = .system {
        didSet {
            // When currentLanguage changes (e.g. via updateFromSettings), reload translations
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
        updateFromSettings()
    }
    
    func updateFromSettings() {
        // 1. Check for Widget Override
        if let widgetOverride = UserDefaults(suiteName: "group.com.currencyconverter.shared")?.string(forKey: "widgetConfigLanguage"),
           widgetOverride != "system",
           let lang = Language(rawValue: widgetOverride) {
            if currentLanguage != lang {
                currentLanguage = lang
            }
            return
        }
        
        // 2. Check for App Setting
        if let appLang = Language(rawValue: selectedLanguageRaw) {
            if currentLanguage != appLang {
                currentLanguage = appLang
            }
            return
        }
        
        // 3. Fallback to System
        if currentLanguage != .system {
            currentLanguage = .system
        }
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
        let primaryLangCode = currentLanguage.rawValue
        var translationsFromPrimary: [String: String] = [:]
        var translationsFromEnglishFallback: [String: String] = [:]

        // Helper to find JSON URL - extracted from the original loadLanguage
        func findJsonUrl(for langCode: String) -> URL? {
            var url = Bundle.main.url(forResource: langCode, withExtension: "json")
            if url == nil { url = Bundle.main.url(forResource: langCode, withExtension: "json", subdirectory: "Localization") }
            if url == nil { url = Bundle.main.url(forResource: langCode, withExtension: "json", subdirectory: "Resources/Localization") }
            if url == nil {
                if let resourcePath = Bundle.main.resourcePath {
                    let fileManager = FileManager.default
                    if let enumerator = fileManager.enumerator(atPath: resourcePath) {
                        for case let file as String in enumerator {
                            if file.hasSuffix("\(langCode).json") {
                                url = Bundle.main.bundleURL.appendingPathComponent(file)
                                break
                            }
                        }
                    }
                }
            }
            return url
        }

        // 1. Attempt to load the primary language JSON
        if let primaryUrl = findJsonUrl(for: primaryLangCode) {
            do {
                let data = try Data(contentsOf: primaryUrl)
                let json = try JSONDecoder().decode([String: [String: String]].self, from: data)
                for (key, details) in json {
                    // Prefer primary language value
                    if let val = details[primaryLangCode] {
                        translationsFromPrimary[key] = val
                    } else if let val = details["en"] { // Fallback to 'en' within the primary file
                        translationsFromPrimary[key] = val
                    } else {
                        translationsFromPrimary[key] = key
                    }
                }
            } catch {
                print("Error loading primary language JSON (\(primaryLangCode)): \(error)")
            }
        } else {
            print("Could not find primary language JSON for '\(primaryLangCode)'")
        }

        // 2. Load the English JSON as a general fallback, unless English is the primary language
        // This ensures a complete English set, even if primary language file failed to load.
        if primaryLangCode != "en" {
            if let enUrl = findJsonUrl(for: "en") {
                do {
                    let data = try Data(contentsOf: enUrl)
                    let json = try JSONDecoder().decode([String: [String: String]].self, from: data)
                    for (key, details) in json {
                        if let val = details["en"] {
                            translationsFromEnglishFallback[key] = val
                        } else {
                            translationsFromEnglishFallback[key] = key
                        }
                    }
                } catch {
                    print("Error loading English fallback JSON: \(error)")
                }
            } else {
                print("Could not find English fallback JSON file.")
            }
        }
        
        // 3. Merge translations: English fallback first, then primary language (overwriting English where available)
        var finalTranslations = translationsFromEnglishFallback
        for (key, value) in translationsFromPrimary {
            finalTranslations[key] = value
        }
        
        self.translations = finalTranslations
    }
}
