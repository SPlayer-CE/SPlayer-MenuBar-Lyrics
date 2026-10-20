import AppKit
import ServiceManagement
import SwiftUI

/// 设置面板
struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var client: SPlayerClient
    @ObservedObject var favoriteBridge: FavoriteBridge

    @State private var configHint = ""
    @State private var launchAtLogin = false
    @State private var launchError = ""

    var body: some View {
        Form {
            connectionSection
            menuBarSection
            favoriteSection
            languageSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onAppear {
            detectConfig(silent: true)
            refreshLoginState()
        }
        .onChange(of: prefs.language) { _ in
            detectConfig(silent: true)
        }
    }

    private var connectionSection: some View {
        Section(L10n.t(.sectionConnection)) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(client.statusText)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button(L10n.t(.reconnect)) { client.restart() }
                    .controlSize(.small)
            }

            HStack(spacing: 8) {
                Text(L10n.t(.websocketPush))
                Spacer()
                Text(L10n.t(client.wsConnected ? .connected : .notConnected))
                    .font(.caption)
                    .foregroundStyle(client.wsConnected ? Color.green : Color.secondary)
            }

            HStack {
                Text(L10n.t(.externalApiPort))
                Spacer()
                TextField(L10n.t(.portPlaceholder), value: $prefs.port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Button(L10n.t(.readConfig)) { detectConfig(silent: false) }
                    .controlSize(.small)
            }

            if !configHint.isEmpty {
                Text(configHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(L10n.t(.connectionHint))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(L10n.t(.openSPlayer)) { SPlayerConfigReader.activate() }
                Button(L10n.t(.refreshLyrics)) { client.refreshLyrics() }
            }
        }
    }

    private var menuBarSection: some View {
        Section(L10n.t(.sectionMenuBar)) {
            Toggle(L10n.t(.showMenuBarLyrics), isOn: $prefs.menuBarLyricsEnabled)

            if prefs.menuBarLyricsEnabled {
                HStack(spacing: 8) {
                    Text(L10n.t(.displayWidth))
                    Text("100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $prefs.menuBarWidth, in: 100...600, step: 1)
                    Text("600")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(prefs.menuBarWidth)) px")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }

                HStack {
                    Text(L10n.t(.lyricAlignment))
                    Spacer()
                    Picker("", selection: $prefs.menuBarAlignment) {
                        ForEach(LyricAlignment.allCases) { alignment in
                            Text(L10n.t(alignment.labelKey)).tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }

                HStack {
                    Text(L10n.t(.iconPosition))
                    Spacer()
                    Picker("", selection: $prefs.menuBarIconPosition) {
                        ForEach(MenuBarIconPosition.allCases) { position in
                            Text(L10n.t(position.labelKey)).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 280)
                }

                Toggle(L10n.t(.wordByWord), isOn: $prefs.menuBarWordByWord)
                Text(L10n.t(.wordByWordHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(L10n.t(.alwaysShowControls), isOn: $prefs.menuBarAlwaysVisible)
                Text(L10n.t(.alwaysShowControlsHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(L10n.t(.widthHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Toggle(L10n.t(.launchAtLogin), isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLoginItem(enabled: newValue)
                    }
            }
            if !launchError.isEmpty {
                Text(launchError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var favoriteSection: some View {
        Section(L10n.t(.sectionFavorite)) {
            HStack(spacing: 8) {
                Circle()
                    .fill(favoriteBridge.pluginConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(L10n.t(favoriteBridge.pluginConnected ? .pluginConnected : .waitingPlugin))
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(L10n.t(favoriteBridge.listening ? .bridgeListening : .bridgeNotListening))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.t(.refreshConnection)) { favoriteBridge.refresh() }
                    .controlSize(.small)
            }

            Text(L10n.t(.favoritePluginHint))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(L10n.t(.revealPlugin)) { revealPlugin() }
                    .disabled(PluginBundle.url() == nil)
                Button(L10n.t(.openSPlayer)) { SPlayerConfigReader.activate() }
            }

            Text(L10n.t(.localBridge))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var languageSection: some View {
        Section(L10n.t(.sectionLanguage)) {
            Picker(L10n.t(.interfaceLanguage), selection: $prefs.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func revealPlugin() {
        guard let url = PluginBundle.url() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private var aboutSection: some View {
        Section(L10n.t(.sectionAbout)) {
            Text(L10n.t(.aboutText))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(L10n.t(.shortcutHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appVersion)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 版本号来自 Info.plist；直接 `swift run` 时回退到源码内版本
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "v\(version ?? "1.1.0")"
    }

    private var statusColor: Color {
        switch client.status {
        case .connected: return .green
        case .connecting: return .orange
        case .disabled: return .yellow
        case .unreachable: return .red
        }
    }

    private func detectConfig(silent: Bool) {
        guard let config = SPlayerConfigReader.read() else {
            configHint = silent ? "" : L10n.t(.configNotFound)
            return
        }
        if prefs.port != config.port {
            prefs.port = config.port
        }
        if !config.enabled {
            configHint = L10n.format(.configPortDisabled, config.port)
        } else if !config.wsEnabled {
            configHint = L10n.format(.configPortNoWebSocket, config.port)
        } else {
            configHint = L10n.format(.configPortOK, config.port)
        }
    }

    private func refreshLoginState() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func updateLoginItem(enabled: Bool) {
        launchError = ""
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchError = L10n.format(.launchAtLoginError, error.localizedDescription)
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

enum PluginBundle {
    /// 收藏桥接插件文件：优先取应用包内资源，开发时回退到仓库目录
    static func url() -> URL? {
        if let url = Bundle.main.url(forResource: "favorite-bridge", withExtension: "js") {
            return url
        }
        let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("plugin/favorite-bridge.js")
        return FileManager.default.fileExists(atPath: source.path) ? source : nil
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    init(prefs: Preferences, client: SPlayerClient, favoriteBridge: FavoriteBridge) {
        let view = SettingsView(
            prefs: prefs,
            client: client,
            favoriteBridge: favoriteBridge
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.t(.settingsWindowTitle)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 720))
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        window?.title = L10n.t(.settingsWindowTitle)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
