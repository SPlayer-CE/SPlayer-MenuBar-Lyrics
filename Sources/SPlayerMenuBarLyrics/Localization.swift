import Foundation

/// 界面语言；`system` 跟随系统首选语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case chinese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.t(.languageSystem)
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
}

/// 所有界面文案的键
enum L10nKey: String, CaseIterable {
    case appName
    case unknownArtist
    case unknownAlbum

    case statusConnecting
    case statusConnected
    case statusApiOff
    case statusUnreachable
    case statusConnectingSPlayer
    case statusConnectedIdle
    case statusConnectedPlaying
    case statusConnectedPaused
    case statusUnreachablePlayer
    case statusUnreachableDetail
    case invalidPort
    case invalidResponse
    case enableApiHint
    case playerNotRunning
    case connectionTimedOut

    case previousTrack
    case nextTrack
    case play
    case pause
    case favorite
    case unfavorite
    case favoriteUnavailable
    case showMenuBarLyrics
    case wordByWord
    case alwaysShowControls
    case trackInfo
    case lyricOffset
    case reset
    case settingsMenu
    case openSPlayer
    case githubRepository
    case starOnGitHub
    case quit

    case settingsWindowTitle
    case sectionConnection
    case reconnect
    case websocketPush
    case connected
    case notConnected
    case externalApiPort
    case portPlaceholder
    case readConfig
    case connectionHint
    case refreshLyrics
    case configNotFound
    case configPortDisabled
    case configPortNoWebSocket
    case configPortOK
    case splayerVersion

    case sectionMenuBar
    case displayWidth
    case autoWidth
    case autoWidthHint
    case fontSize
    case lyricAlignment
    case alignLeft
    case alignCenter
    case alignRight
    case iconPosition
    case iconLeft
    case iconRight
    case iconHidden
    case wordByWordHint
    case alwaysShowControlsHint
    case widthHint
    case launchAtLogin
    case launchAtLoginError
    case trackHUD
    case trackHUDHint
    case lyricOffsetHint

    case sectionFavorite
    case pluginConnected
    case waitingPlugin
    case bridgeListening
    case bridgeNotListening
    case refreshConnection
    case favoritePluginHint
    case revealPlugin
    case localBridge

    case sectionLanguage
    case interfaceLanguage
    case languageSystem

    case sectionAbout
    case aboutText
    case shortcutHint
    case checkForUpdates
    case checkingForUpdates
    case upToDate
    case updateAvailable
    case updateCheckFailed
    case updateCheckFailedDetail
    case openReleasePage
    case autoCheckUpdates
    case diagnostics
    case copyDiagnostics
    case diagnosticsCopied
}

/// 极简本地化：语言由偏好设置决定，缺失的键回退到英文
enum L10n {
    nonisolated(unsafe) static var language: AppLanguage = .system

    nonisolated static var isChinese: Bool {
        switch language {
        case .system:
            return (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")
        case .chinese:
            return true
        case .english:
            return false
        }
    }

    nonisolated static func t(_ key: L10nKey) -> String {
        let table = isChinese ? chinese : english
        return table[key] ?? english[key] ?? key.rawValue
    }

    nonisolated static func format(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }

    static let chinese: [L10nKey: String] = [
        .appName: "SPlayer 菜单栏歌词",
        .unknownArtist: "未知艺术家",
        .unknownAlbum: "未知专辑",

        .statusConnecting: "正在连接",
        .statusConnected: "已连接",
        .statusApiOff: "外部 API 未开启",
        .statusUnreachable: "无法连接",
        .statusConnectingSPlayer: "正在连接 SPlayer-Next…",
        .statusConnectedIdle: "已连接 · 暂无播放",
        .statusConnectedPlaying: "已连接 · 正在播放",
        .statusConnectedPaused: "已连接 · 已暂停",
        .statusUnreachablePlayer: "无法连接 SPlayer-Next",
        .statusUnreachableDetail: "无法连接 · %@",
        .invalidPort: "端口无效",
        .invalidResponse: "响应无效",
        .enableApiHint: "请在 SPlayer-Next 设置 → 外部 API 中开启",
        .playerNotRunning: "SPlayer-Next 未运行或端口未开放",
        .connectionTimedOut: "连接超时",

        .previousTrack: "上一首",
        .nextTrack: "下一首",
        .play: "播放",
        .pause: "暂停",
        .favorite: "收藏",
        .unfavorite: "取消收藏",
        .favoriteUnavailable: "收藏（需要安装桥接插件并登录网易云）",
        .showMenuBarLyrics: "菜单栏展示歌词",
        .wordByWord: "逐字高亮",
        .alwaysShowControls: "菜单栏常驻操控",
        .trackInfo: "歌曲信息…",
        .lyricOffset: "歌词偏移",
        .reset: "重置",
        .settingsMenu: "设置…",
        .openSPlayer: "打开 SPlayer-Next",
        .githubRepository: "GitHub 仓库",
        .starOnGitHub: "在 GitHub 上点个 Star",
        .quit: "退出",

        .settingsWindowTitle: "SPlayer 菜单栏歌词设置",
        .sectionConnection: "连接 SPlayer-Next",
        .reconnect: "重新连接",
        .websocketPush: "WebSocket 推送",
        .connected: "已连接",
        .notConnected: "未连接",
        .externalApiPort: "外部 API 端口",
        .portPlaceholder: "端口",
        .readConfig: "读取 SPlayer 配置",
        .connectionHint: "在 SPlayer-Next 中打开：设置 → 外部 API，开启「外部 API」；建议同时开启「WebSocket」，切歌与歌词更新会即时到达。",
        .refreshLyrics: "刷新歌词",
        .configNotFound: "未找到 SPlayer-Next 的配置文件",
        .configPortDisabled: "已读取端口 %d：外部 API 当前未开启",
        .configPortNoWebSocket: "已读取端口 %d：外部 API 已开启，WebSocket 未开启",
        .configPortOK: "已读取端口 %d：配置正常",
        .splayerVersion: "SPlayer-Next 版本",

        .sectionMenuBar: "菜单栏歌词",
        .displayWidth: "展示宽度",
        .autoWidth: "自动宽度",
        .autoWidthHint: "按当前歌词长度自动调整，展示宽度作为上限。",
        .fontSize: "字号",
        .lyricAlignment: "歌词对齐",
        .alignLeft: "靠左",
        .alignCenter: "居中",
        .alignRight: "靠右",
        .iconPosition: "图标位置",
        .iconLeft: "歌词左侧",
        .iconRight: "歌词右侧",
        .iconHidden: "不显示",
        .wordByWordHint: "仅对带真实逐字时间的歌词（QRC / YRC / TTML）生效；LRC 整行歌词保持静态。",
        .alwaysShowControlsHint: "在菜单栏常驻显示「上一首 / 播放·暂停 / 下一首」按钮；关闭后仅在载入歌曲时显示。",
        .widthHint: "展示宽度是上限；菜单栏空间不足（含刘海屏）时会自动收窄，避免被系统隐藏。",
        .launchAtLogin: "开机自动启动",
        .launchAtLoginError: "设置开机启动失败：%@",
        .trackHUD: "切歌时显示 HUD",
        .trackHUDHint: "在菜单栏下方短暂显示歌名、歌手和封面。",
        .lyricOffsetHint: "如果歌词整体偏早或偏晚，可以在这里微调。",

        .sectionFavorite: "收藏按钮",
        .pluginConnected: "桥接插件已连接",
        .waitingPlugin: "等待桥接插件",
        .bridgeListening: "桥接端口已监听",
        .bridgeNotListening: "桥接端口未启动",
        .refreshConnection: "刷新连接",
        .favoritePluginHint: "收藏按钮需要一个 SPlayer-Next 插件，不会修改客户端源码。请先升级到 v1.2.0-nightly.990 或更高版本，然后在 SPlayer-Next 的 设置 → 插件管理 → 本地导入 中选择 favorite-bridge.js，并授予 network / api 权限。",
        .revealPlugin: "在 Finder 中显示插件文件",
        .localBridge: "本地桥接：127.0.0.1:14561（仅本机）",

        .sectionLanguage: "语言",
        .interfaceLanguage: "界面语言",
        .languageSystem: "跟随系统",

        .sectionAbout: "关于",
        .aboutText: "SPlayer 菜单栏歌词是一个独立的小工具：它通过 SPlayer-Next 的外部 API 获取歌词与播放进度，并把当前歌词显示在 macOS 菜单栏中，不会修改 SPlayer-Next 本身。",
        .shortcutHint: "快捷键：⌘, 打开设置",
        .checkForUpdates: "检查更新",
        .checkingForUpdates: "正在检查…",
        .upToDate: "已是最新版本（v%@）",
        .updateAvailable: "发现新版本 v%@",
        .updateCheckFailed: "检查更新失败",
        .updateCheckFailedDetail: "检查更新失败：%@",
        .openReleasePage: "打开发布页",
        .autoCheckUpdates: "启动时自动检查更新",
        .diagnostics: "诊断",
        .copyDiagnostics: "复制诊断信息",
        .diagnosticsCopied: "已复制到剪贴板",
    ]

    static let english: [L10nKey: String] = [
        .appName: "SPlayer Menu Bar Lyrics",
        .unknownArtist: "Unknown artist",
        .unknownAlbum: "Unknown album",

        .statusConnecting: "Connecting",
        .statusConnected: "Connected",
        .statusApiOff: "External API is off",
        .statusUnreachable: "Unable to connect",
        .statusConnectingSPlayer: "Connecting to SPlayer-Next…",
        .statusConnectedIdle: "Connected · Nothing playing",
        .statusConnectedPlaying: "Connected · Playing",
        .statusConnectedPaused: "Connected · Paused",
        .statusUnreachablePlayer: "Unable to connect to SPlayer-Next",
        .statusUnreachableDetail: "Unable to connect · %@",
        .invalidPort: "Invalid port",
        .invalidResponse: "Invalid response",
        .enableApiHint: "Enable it in SPlayer-Next → Settings → External API",
        .playerNotRunning: "SPlayer-Next is not running or the port is closed",
        .connectionTimedOut: "Connection timed out",

        .previousTrack: "Previous",
        .nextTrack: "Next",
        .play: "Play",
        .pause: "Pause",
        .favorite: "Favorite",
        .unfavorite: "Remove from favorites",
        .favoriteUnavailable: "Favorite (requires the bridge plugin and a NetEase login)",
        .showMenuBarLyrics: "Show lyrics in the menu bar",
        .wordByWord: "Word-by-word highlight",
        .alwaysShowControls: "Always show controls",
        .trackInfo: "Track Info…",
        .lyricOffset: "Lyric offset",
        .reset: "Reset",
        .settingsMenu: "Settings…",
        .openSPlayer: "Open SPlayer-Next",
        .githubRepository: "GitHub repository",
        .starOnGitHub: "Star on GitHub",
        .quit: "Quit",

        .settingsWindowTitle: "SPlayer Menu Bar Lyrics Settings",
        .sectionConnection: "Connect to SPlayer-Next",
        .reconnect: "Reconnect",
        .websocketPush: "WebSocket push",
        .connected: "Connected",
        .notConnected: "Not connected",
        .externalApiPort: "External API port",
        .portPlaceholder: "Port",
        .readConfig: "Read SPlayer config",
        .connectionHint: "In SPlayer-Next open Settings → External API and turn on “External API”; enabling “WebSocket” as well makes track and lyric changes arrive instantly.",
        .refreshLyrics: "Refresh lyrics",
        .configNotFound: "SPlayer-Next config file not found",
        .configPortDisabled: "Port %d loaded: the External API is currently off",
        .configPortNoWebSocket: "Port %d loaded: External API is on, WebSocket is off",
        .configPortOK: "Port %d loaded: configuration looks good",
        .splayerVersion: "SPlayer-Next version",

        .sectionMenuBar: "Menu bar lyrics",
        .displayWidth: "Display width",
        .autoWidth: "Automatic width",
        .autoWidthHint: "Fit the current lyric; the display width is used as the maximum.",
        .fontSize: "Font size",
        .lyricAlignment: "Lyric alignment",
        .alignLeft: "Left",
        .alignCenter: "Center",
        .alignRight: "Right",
        .iconPosition: "Icon position",
        .iconLeft: "Left of lyrics",
        .iconRight: "Right of lyrics",
        .iconHidden: "Hidden",
        .wordByWordHint: "Only applies to lyrics with real word timings (QRC / YRC / TTML); plain LRC lines stay static.",
        .alwaysShowControlsHint: "Keep Previous / Play–Pause / Next in the menu bar; when off they only appear while a track is loaded.",
        .widthHint: "Display width is a maximum; the item narrows automatically when menu bar space is tight, including around the notch.",
        .launchAtLogin: "Launch at login",
        .launchAtLoginError: "Failed to update launch at login: %@",
        .trackHUD: "Show HUD on track change",
        .trackHUDHint: "Briefly show the title, artist, and artwork below the menu bar.",
        .lyricOffsetHint: "Adjust if the lyrics run ahead of or behind the audio.",

        .sectionFavorite: "Favorite button",
        .pluginConnected: "Bridge plugin connected",
        .waitingPlugin: "Waiting for the bridge plugin",
        .bridgeListening: "Bridge port listening",
        .bridgeNotListening: "Bridge port not listening",
        .refreshConnection: "Refresh connection",
        .favoritePluginHint: "The favorite button needs a SPlayer-Next plugin and never modifies the client source. Upgrade to v1.2.0-nightly.990 or newer, then choose favorite-bridge.js in SPlayer-Next → Settings → Plugins → Import local, and grant the network / api permissions.",
        .revealPlugin: "Reveal plugin file in Finder",
        .localBridge: "Local bridge: 127.0.0.1:14561 (this Mac only)",

        .sectionLanguage: "Language",
        .interfaceLanguage: "Interface language",
        .languageSystem: "System",

        .sectionAbout: "About",
        .aboutText: "SPlayer Menu Bar Lyrics is a standalone utility. It reads lyrics and playback progress from SPlayer-Next's external API and shows the current line in the macOS menu bar without modifying SPlayer-Next itself.",
        .shortcutHint: "Shortcut: ⌘, opens settings",
        .checkForUpdates: "Check for updates",
        .checkingForUpdates: "Checking…",
        .upToDate: "Up to date (v%@)",
        .updateAvailable: "Version v%@ is available",
        .updateCheckFailed: "Update check failed",
        .updateCheckFailedDetail: "Update check failed: %@",
        .openReleasePage: "Open release page",
        .autoCheckUpdates: "Check for updates at launch",
        .diagnostics: "Diagnostics",
        .copyDiagnostics: "Copy diagnostics",
        .diagnosticsCopied: "Copied to clipboard",
    ]
}
