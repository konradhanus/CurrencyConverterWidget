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
            
            // Check if the system language is supported
            if let _ = Language(rawValue: sys) {
                langCodeToLoad = sys
                valueKey = sys
            } else {
                langCodeToLoad = "en" // Fallback to English
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
