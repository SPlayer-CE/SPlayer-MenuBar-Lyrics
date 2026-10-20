import Combine
import Foundation

/// 菜单栏歌词的水平对齐方式
enum LyricAlignment: String, CaseIterable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .left: return .alignLeft
        case .center: return .alignCenter
        case .right: return .alignRight
        }
    }
}

/// 菜单栏歌词左侧音乐图标的位置
enum MenuBarIconPosition: String, CaseIterable, Identifiable {
    case left
    case right
    case hidden

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .left: return .iconLeft
        case .right: return .iconRight
        case .hidden: return .iconHidden
        }
    }
}

/// 用户配置，全部落到 UserDefaults
@MainActor
final class Preferences: ObservableObject {
    private enum Key {
        static let port = "port"
        static let menuBarLyricsEnabled = "menuBarLyricsEnabled"
        static let menuBarWidth = "menuBarWidth"
        static let menuBarWordByWord = "menuBarWordByWord"
        static let menuBarAlwaysVisible = "menuBarAlwaysVisible"
        static let menuBarAlignment = "menuBarAlignment"
        static let menuBarIconPosition = "menuBarIconPosition"
        static let language = "language"
    }

    private let defaults = UserDefaults.standard
    private var isLoading = true

    @Published var port: Int { didSet { persist() } }
    @Published var menuBarLyricsEnabled: Bool { didSet { persist() } }
    @Published var menuBarWidth: Double { didSet { persist() } }
    @Published var menuBarWordByWord: Bool { didSet { persist() } }
    @Published var menuBarAlwaysVisible: Bool { didSet { persist() } }
    @Published var menuBarAlignment: LyricAlignment { didSet { persist() } }
    @Published var menuBarIconPosition: MenuBarIconPosition { didSet { persist() } }
    @Published var language: AppLanguage {
        didSet {
            L10n.language = language
            persist()
        }
    }

    /// 改名前的 Bundle ID，用于迁移旧偏好
    private static let legacyDefaultsDomain = "com.beichen.SPlayerFinderLyrics"

    init() {
        Self.migrateLegacyDefaultsIfNeeded()
        defaults.register(defaults: [
            Key.port: 14558,
            Key.menuBarLyricsEnabled: true,
            Key.menuBarWidth: 287.0,
            Key.menuBarWordByWord: true,
            Key.menuBarAlwaysVisible: true,
            Key.menuBarAlignment: LyricAlignment.left.rawValue,
            Key.menuBarIconPosition: MenuBarIconPosition.left.rawValue,
            Key.language: AppLanguage.system.rawValue,
        ])

        port = defaults.integer(forKey: Key.port)
        menuBarLyricsEnabled = defaults.bool(forKey: Key.menuBarLyricsEnabled)
        menuBarWidth = defaults.double(forKey: Key.menuBarWidth)
        menuBarWordByWord = defaults.bool(forKey: Key.menuBarWordByWord)
        menuBarAlwaysVisible = defaults.bool(forKey: Key.menuBarAlwaysVisible)
        menuBarAlignment = LyricAlignment(
            rawValue: defaults.string(forKey: Key.menuBarAlignment) ?? ""
        ) ?? .left
        menuBarIconPosition = MenuBarIconPosition(
            rawValue: defaults.string(forKey: Key.menuBarIconPosition) ?? ""
        ) ?? .left
        language = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "")
            ?? .system
        L10n.language = language
        isLoading = false
    }

    private func persist() {
        guard !isLoading else { return }
        defaults.set(port, forKey: Key.port)
        defaults.set(menuBarLyricsEnabled, forKey: Key.menuBarLyricsEnabled)
        defaults.set(menuBarWidth, forKey: Key.menuBarWidth)
        defaults.set(menuBarWordByWord, forKey: Key.menuBarWordByWord)
        defaults.set(menuBarAlwaysVisible, forKey: Key.menuBarAlwaysVisible)
        defaults.set(menuBarAlignment.rawValue, forKey: Key.menuBarAlignment)
        defaults.set(menuBarIconPosition.rawValue, forKey: Key.menuBarIconPosition)
        defaults.set(language.rawValue, forKey: Key.language)
    }

    /// 改名后 Bundle ID 变了，首次启动把旧域里的设置搬过来
    private static func migrateLegacyDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let marker = "migratedFromLegacyDomain"
        guard !defaults.bool(forKey: marker) else { return }
        defaults.set(true, forKey: marker)
        guard let legacy = UserDefaults(suiteName: legacyDefaultsDomain) else { return }
        let keys = [
            Key.port,
            Key.menuBarLyricsEnabled,
            Key.menuBarWidth,
            Key.menuBarWordByWord,
            Key.menuBarAlwaysVisible,
            Key.menuBarAlignment,
            Key.menuBarIconPosition,
            Key.language,
        ]
        for key in keys where defaults.object(forKey: key) == nil {
            if let value = legacy.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
    }
}
