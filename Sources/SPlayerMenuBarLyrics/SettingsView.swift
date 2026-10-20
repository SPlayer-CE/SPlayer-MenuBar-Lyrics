import AppKit
import ServiceManagement
import SwiftUI

/// 设置面板
struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var client: SPlayerClient
    @ObservedObject var favoriteBridge: FavoriteBridge
    @ObservedObject var updateChecker: UpdateChecker

    @State private var configHint = ""
    @State private var launchAtLogin = false
    @State private var launchError = ""
    @State private var diagnosticsCopied = false

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

            HStack(spacing: 8) {
                Text(L10n.t(.splayerVersion))
                Spacer()
                Text(client.serverVersion ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                Toggle(L10n.t(.autoWidth), isOn: $prefs.menuBarAutoWidth)
                Text(L10n.t(.autoWidthHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(L10n.t(.fontSize))
                    Slider(value: $prefs.menuBarFontSize, in: 11...16, step: 1)
                    Text("\(Int(prefs.menuBarFontSize)) pt")
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

                Toggle(L10n.t(.trackHUD), isOn: $prefs.showTrackHUD)
                Text(L10n.t(.trackHUDHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(L10n.t(.lyricOffset))
                    Spacer()
                    Text(lyricOffsetText)
                        .monospacedDigit()
                        .frame(width: 64, alignment: .trailing)
                    Stepper(
                        "",
                        value: $prefs.userLyricOffsetMs,
                        in: -3000...3000,
                        step: 100
                    )
                    .labelsHidden()
                    Button(L10n.t(.reset)) {
                        prefs.userLyricOffsetMs = 0
                    }
                    .controlSize(.small)
                    .disabled(abs(prefs.userLyricOffsetMs) < 0.5)
                }
                Text(L10n.t(.lyricOffsetHint))
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
                Text(appVersion)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(L10n.t(.checkForUpdates)) {
                    Task { await updateChecker.check() }
                }
                .controlSize(.small)
                .disabled(updateChecker.state == .checking)
            }

            updateStatus

            Toggle(L10n.t(.autoCheckUpdates), isOn: $prefs.autoCheckUpdates)
                .toggleStyle(.checkbox)

            HStack {
                Button(L10n.t(.copyDiagnostics)) {
                    copyDiagnostics()
                }
                .controlSize(.small)
                if diagnosticsCopied {
                    Text(L10n.t(.diagnosticsCopied))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                Text(L10n.t(.shortcutHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updateChecker.state {
        case .idle:
            EmptyView()
        case .checking:
            updateStatusText(L10n.t(.checkingForUpdates))
        case .upToDate(let version):
            updateStatusText(L10n.format(.upToDate, version))
        case .available(let version, let url):
            HStack(spacing: 8) {
                Text(L10n.format(.updateAvailable, version))
                    .font(.caption)
                Button(L10n.t(.openReleasePage)) {
                    NSWorkspace.shared.open(url)
                }
                .controlSize(.small)
            }
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func updateStatusText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func copyDiagnostics() {
        let text = Diagnostics.text(
            prefs: prefs,
            client: client,
            favoriteBridge: favoriteBridge
        )
        Diagnostics.copyToPasteboard(text)
        diagnosticsCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            diagnosticsCopied = false
        }
    }

    private var lyricOffsetText: String {
        if abs(prefs.userLyricOffsetMs) < 0.5 { return "0.0 s" }
        return String(format: "%+.1f s", prefs.userLyricOffsetMs / 1000)
    }

    /// 版本号来自 Info.plist；直接 `swift run` 时回退到 dev
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "v\(version ?? "dev")"
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
    init(
        prefs: Preferences,
        client: SPlayerClient,
        favoriteBridge: FavoriteBridge,
        updateChecker: UpdateChecker
    ) {
        let view = SettingsView(
            prefs: prefs,
            client: client,
            favoriteBridge: favoriteBridge,
            updateChecker: updateChecker
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.t(.settingsWindowTitle)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 520, height: 780))
        window.minSize = NSSize(width: 520, height: 560)
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
