import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences()
    private let favoriteBridge = FavoriteBridge()
    private let updateChecker = UpdateChecker()
    private let trackHUD = TrackHUDController()
    private lazy var client = SPlayerClient(prefs: prefs)
    private lazy var trackInfoPopover = TrackInfoPopoverController(client: client)
    private var settingsController: SettingsWindowController!
    private var statusItem: NSStatusItem!
    private var lyricView: MenuBarLyricView!
    private var cancellables = Set<AnyCancellable>()
    private var screenObserverTokens: [NSObjectProtocol] = []
    private var menuBarTimer: Timer?

    private var lastAutoWidthKey = ""
    private var lastHUDTrackID: String?

#if DEBUG
    private var lastDebugTitle = ""
    private var lastControlState = ""
#endif
    private var cachedLineIndex = -2
    private var cachedLineText = ""
    private var cachedWordByWord = false
    private var cachedTimings: [CharacterTiming] = []

#if DEBUG
    private let debugEnabled = ProcessInfo.processInfo.environment["SPlayerMenuBarLyricsDebug"] == "1"
#endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        adoptPortFromSPlayerConfig()

        settingsController = SettingsWindowController(
            prefs: prefs,
            client: client,
            favoriteBridge: favoriteBridge,
            updateChecker: updateChecker
        )
        setupStatusItem()
        observe()
        observeScreens()
        client.start()
        refreshMenu()
        syncMenuBarTicker()

        if prefs.autoCheckUpdates {
            Task { [weak self] in
                await self?.updateChecker.autoCheckIfNeeded()
            }
        }

#if DEBUG
        // 调试：模拟点击红心，便于验证桥接请求
        if CommandLine.arguments.contains("--test-favorite") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.toggleFavorite()
            }
        }

        // 调试：模拟点击「刷新连接」
        if CommandLine.arguments.contains("--test-refresh") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.favoriteBridge.refresh()
            }
        }

        // 调试：启动后直接打开设置窗口，便于验证 SwiftUI 布局
        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openSettings()
            }
        }
#endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopMenuBarTicker()
        trackHUD.hide(animated: false)
        trackInfoPopover.close()
        for token in screenObserverTokens {
            NotificationCenter.default.removeObserver(token)
        }
        screenObserverTokens.removeAll()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        statusItem?.isVisible = true
        updateMenuBarLyric()
        openSettings()
        return true
    }

    // MARK: - 状态栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(prefs.menuBarWidth))
        lyricView = MenuBarLyricView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: prefs.menuBarWidth,
                height: NSStatusBar.system.thickness
            )
        )
        lyricView.autoresizingMask = [.width, .height]
        lyricView.onPrevious = { [weak self] in self?.client.previousTrack() }
        lyricView.onTogglePlayback = { [weak self] in self?.client.togglePlayback() }
        lyricView.onNext = { [weak self] in self?.client.nextTrack() }
        lyricView.onToggleFavorite = { [weak self] in self?.toggleFavorite() }

        if let button = statusItem.button {
            button.image = nil
            button.title = ""
            button.toolTip = L10n.t(.appName)
            button.addSubview(lyricView)
            lyricView.frame = button.bounds
            lyricView.setFontSize(CGFloat(prefs.menuBarFontSize))
        }
        statusItem.menu = NSMenu()
    }

    /// 更新歌词项右侧的控制按钮与播放图标
    private func refreshControls() {
        guard let lyricView else { return }
        let connected = client.status == .connected
        let show = prefs.menuBarLyricsEnabled
            && connected
            && (prefs.menuBarAlwaysVisible || client.track != nil)
        lyricView.setControlsVisible(show)
        lyricView.applyLocalizedTooltips()
        lyricView.setPlaying(client.isPlaying)
        updateHeart()

#if DEBUG
        let state = "\(show)-\(client.isPlaying)"
        if debugEnabled, state != lastControlState {
            lastControlState = state
            print("[SPlayerMenuBarLyrics] 控制按钮 显示=\(show) 播放=\(client.isPlaying)")
            fflush(stdout)
        }
#endif
    }

    /// 同步当前曲目的红心状态
    private func updateHeart() {
        guard let lyricView else { return }
        let track = client.track
        let supported = track?.source == "netease"
        let favorite = track.flatMap { favoriteBridge.favorite(for: $0.id) } ?? false
        let available = track.flatMap { favoriteBridge.available(for: $0.id) }
            ?? favoriteBridge.pluginConnected
        lyricView.setFavorite(favorite: favorite, supported: supported, available: available)
    }

    private func toggleFavorite() {
        guard favoriteBridge.pluginConnected else { return }
        guard let track = client.track, track.source == "netease" else { return }
        let current = favoriteBridge.favorite(for: track.id) ?? false
        favoriteBridge.requestToggle(trackId: track.id, favorite: !current)
        updateHeart()
    }

    private func refreshMenu() {
        guard let statusItem else { return }
        lyricView?.setIcon(connected: client.status == .connected)

        let menu = NSMenu()

        let status = NSMenuItem()
        status.attributedTitle = NSAttributedString(
            string: "● \(client.statusText)",
            attributes: [
                .font: NSFont.menuFont(ofSize: 12),
                .foregroundColor: statusColor,
            ]
        )
        status.isEnabled = false
        menu.addItem(status)

        if let track = client.track {
            let titleItem = menuItem(track.title, #selector(showTrackInfo), key: "")
            titleItem.toolTip = L10n.t(.trackInfo)
            menu.addItem(titleItem)
            let artistItem = NSMenuItem(
                title: track.artistsText,
                action: nil,
                keyEquivalent: ""
            )
            artistItem.isEnabled = false
            menu.addItem(artistItem)
        }

        menu.addItem(.separator())

        let connected = client.status == .connected
        let previous = menuItem(L10n.t(.previousTrack), #selector(previousTrack), key: "")
        let toggle = menuItem(
            L10n.t(client.isPlaying ? .pause : .play),
            #selector(togglePlayback),
            key: ""
        )
        let next = menuItem(L10n.t(.nextTrack), #selector(nextTrack), key: "")
        for item in [previous, toggle, next] {
            item.isEnabled = connected
            menu.addItem(item)
        }
        menu.addItem(.separator())

        menu.addItem(
            checkItem(
                L10n.t(.showMenuBarLyrics),
                #selector(toggleMenuBarLyrics),
                prefs.menuBarLyricsEnabled
            )
        )
        menu.addItem(
            checkItem(
                L10n.t(.wordByWord),
                #selector(toggleMenuBarWordByWord),
                prefs.menuBarWordByWord
            )
        )
        menu.addItem(alignmentMenuItem())
        menu.addItem(lyricOffsetMenuItem())
        menu.addItem(
            checkItem(
                L10n.t(.alwaysShowControls),
                #selector(toggleMenuBarAlwaysVisible),
                prefs.menuBarAlwaysVisible
            )
        )
        menu.addItem(.separator())
        if case .available(let version, _) = updateChecker.state {
            menu.addItem(
                menuItem(
                    L10n.format(.updateAvailable, version),
                    #selector(openReleasePage),
                    key: ""
                )
            )
        }
        menu.addItem(menuItem(L10n.t(.settingsMenu), #selector(openSettings), key: ","))
        menu.addItem(menuItem(L10n.t(.openSPlayer), #selector(activateSPlayer), key: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem(L10n.t(.quit), #selector(quit), key: "q"))

        statusItem.menu = menu
        refreshControls()
    }

    private var statusColor: NSColor {
        switch client.status {
        case .connected: return .systemGreen
        case .connecting: return .systemOrange
        case .disabled: return .systemYellow
        case .unreachable: return .systemRed
        }
    }

    private func checkItem(_ title: String, _ action: Selector, _ checked: Bool) -> NSMenuItem {
        let item = menuItem(title, action, key: "")
        item.state = checked ? .on : .off
        return item
    }

    /// 「歌词对齐」子菜单：靠左 / 居中 / 靠右
    private func alignmentMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: L10n.t(.lyricAlignment),
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu()
        for alignment in LyricAlignment.allCases {
            let option = menuItem(
                L10n.t(alignment.labelKey),
                #selector(selectLyricAlignment(_:)),
                key: ""
            )
            option.representedObject = alignment.rawValue
            option.state = prefs.menuBarAlignment == alignment ? .on : .off
            submenu.addItem(option)
        }
        item.submenu = submenu
        return item
    }

    /// 「歌词偏移」子菜单：按 0.1s / 0.5s 微调
    private func lyricOffsetMenuItem() -> NSMenuItem {
        let current = prefs.userLyricOffsetMs
        let item = NSMenuItem(
            title: "\(L10n.t(.lyricOffset)) (\(offsetText(current)))",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu()
        let steps: [(Double, String)] = [
            (-500, "−0.5 s"),
            (-100, "−0.1 s"),
            (0, L10n.t(.reset)),
            (100, "+0.1 s"),
            (500, "+0.5 s"),
        ]
        for (delta, label) in steps {
            let option = menuItem(label, #selector(adjustLyricOffset(_:)), key: "")
            option.representedObject = NSNumber(value: delta)
            if delta == 0 {
                option.isEnabled = abs(current) > 0.5
            }
            submenu.addItem(option)
        }
        item.submenu = submenu
        return item
    }

    private func offsetText(_ milliseconds: Double) -> String {
        if abs(milliseconds) < 0.5 { return "0.0 s" }
        return String(format: "%+.1f s", milliseconds / 1000)
    }

    private func menuItem(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - 观察

    private func observe() {
        client.$status
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshMenu()
                    self?.updateMenuBarLyric()
                    self?.syncMenuBarTicker()
                }
            }
            .store(in: &cancellables)
        client.$track
            .dropFirst()
            .sink { [weak self] track in
                DispatchQueue.main.async {
                    self?.refreshMenu()
                    self?.updateMenuBarLyric()
                    self?.maybeShowTrackHUD(track)
                }
            }
            .store(in: &cancellables)
        client.$lyrics
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.cachedLineIndex = -2
                    self?.updateMenuBarLyric()
                }
            }
            .store(in: &cancellables)
        client.$isPlaying
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshMenu()
                    self?.updateMenuBarLyric()
                    self?.syncMenuBarTicker()
                }
            }
            .store(in: &cancellables)
        client.$wsConnected
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshMenu() }
            }
            .store(in: &cancellables)
        client.$serverVersion
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshMenu() }
            }
            .store(in: &cancellables)
        favoriteBridge.$revision
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateHeart() }
            }
            .store(in: &cancellables)
        updateChecker.$state
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshMenu() }
            }
            .store(in: &cancellables)
        prefs.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshMenu()
                    self?.updateMenuBarLyric()
                    self?.syncMenuBarTicker()
                }
            }
            .store(in: &cancellables)
    }

    /// 屏幕参数或状态项所在屏幕变化时重新计算可用宽度
    private func observeScreens() {
        let center = NotificationCenter.default
        screenObserverTokens.append(
            center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleScreenChange()
                }
            }
        )
        if let window = statusItem.button?.window {
            screenObserverTokens.append(
                center.addObserver(
                    forName: NSWindow.didChangeScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.handleScreenChange()
                    }
                }
            )
        }
    }

    private func handleScreenChange() {
        lastAutoWidthKey = ""
        refreshMenu()
        updateMenuBarLyric()
    }

    private func maybeShowTrackHUD(_ track: Track?) {
        let previousID = lastHUDTrackID
        if let track {
            lastHUDTrackID = track.id
        }
        guard prefs.showTrackHUD,
              let track,
              let previousID,
              previousID != track.id else { return }
        trackHUD.show(track: track, near: statusItem.button)
    }

    /// 首次启动时沿用 SPlayer-Next 里配置的端口
    private func adoptPortFromSPlayerConfig() {
        guard prefs.port == 14558, let config = SPlayerConfigReader.read() else { return }
        if config.port != prefs.port {
            prefs.port = config.port
        }
    }

    // MARK: - 菜单动作

    @objc private func previousTrack() {
        client.previousTrack()
    }

    @objc private func togglePlayback() {
        client.togglePlayback()
    }

    @objc private func nextTrack() {
        client.nextTrack()
    }

    @objc private func toggleMenuBarLyrics() {
        prefs.menuBarLyricsEnabled.toggle()
        refreshMenu()
        updateMenuBarLyric()
    }

    @objc private func toggleMenuBarWordByWord() {
        prefs.menuBarWordByWord.toggle()
        refreshMenu()
        updateMenuBarLyric()
    }

    @objc private func toggleMenuBarAlwaysVisible() {
        prefs.menuBarAlwaysVisible.toggle()
        refreshMenu()
        updateMenuBarLyric()
    }

    @objc private func selectLyricAlignment(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let alignment = LyricAlignment(rawValue: raw) else { return }
        prefs.menuBarAlignment = alignment
        refreshMenu()
        updateMenuBarLyric()
    }

    @objc private func adjustLyricOffset(_ sender: NSMenuItem) {
        let delta = (sender.representedObject as? NSNumber)?.doubleValue ?? 0
        if delta == 0 {
            prefs.userLyricOffsetMs = 0
        } else {
            prefs.userLyricOffsetMs = min(
                max(prefs.userLyricOffsetMs + delta, -3000),
                3000
            )
        }
        refreshMenu()
        updateMenuBarLyric()
    }

    @objc private func showTrackInfo() {
        guard let button = statusItem.button else { return }
        if trackInfoPopover.isShown {
            trackInfoPopover.close()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            trackInfoPopover.show(relativeTo: button)
        }
    }

    @objc private func openReleasePage() {
        guard case .available(_, let url) = updateChecker.state else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openSettings() {
        settingsController.present()
    }

    @objc private func activateSPlayer() {
        SPlayerConfigReader.activate()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 菜单栏歌词

    /// 只在真正需要动画时运行 30fps 定时器；暂停或未连接时完全停掉
    private func syncMenuBarTicker() {
        let shouldAnimate = prefs.menuBarLyricsEnabled
            && client.status == .connected
            && client.isPlaying
        if shouldAnimate {
            startMenuBarTicker()
        } else {
            stopMenuBarTicker()
            updateMenuBarLyric()
        }
    }

    private func startMenuBarTicker() {
        guard menuBarTimer == nil else { return }
        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(updateMenuBarLyric),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 1.0 / 60.0
        RunLoop.main.add(timer, forMode: .common)
        menuBarTimer = timer
        updateMenuBarLyric()
    }

    private func stopMenuBarTicker() {
        menuBarTimer?.invalidate()
        menuBarTimer = nil
    }

    @objc private func updateMenuBarLyric() {
        guard let statusItem, let lyricView else { return }
        if !statusItem.isVisible {
            statusItem.isVisible = true
        }

        let timeMs = client.currentLyricTimeMs
        var display = ""
        var mainLineUTF16 = 0
        var timings: [CharacterTiming] = []
        var lineStartMs: Double = 0
        var lineEndMs: Double = 0
        var tooltip: [String] = [L10n.t(.appName), client.statusText]

        if prefs.menuBarLyricsEnabled, client.status == .connected {
            let lines = client.timeline.lines
            let index = client.timeline.index(at: timeMs)
            if index >= 0, index < lines.count {
                let line = lines[index]
                display = line.text
                mainLineUTF16 = line.text.utf16.count
                lineStartMs = line.startTime
                lineEndMs = line.endTime

                if prefs.menuBarWordByWord {
                    if cachedLineIndex != index
                        || cachedLineText != line.text
                        || cachedWordByWord != prefs.menuBarWordByWord {
                        cachedTimings = LyricHighlight.timings(for: line)
                        cachedLineIndex = index
                        cachedLineText = line.text
                        cachedWordByWord = prefs.menuBarWordByWord
                    }
                    timings = cachedTimings
                }

                tooltip.append(line.text)
            } else if let track = client.track {
                display = track.title
            }
        }

        if let track = client.track {
            tooltip.insert("\(track.title) — \(track.artistsText)", at: 2)
        }

        lyricView.setIconPosition(prefs.menuBarIconPosition)
        lyricView.setFontSize(CGFloat(prefs.menuBarFontSize))
        let maxWidth = effectiveMaxMenuBarWidth()
        let targetLength = menuBarTargetLength(display: display, maxWidth: maxWidth)
        if abs(statusItem.length - targetLength) > 0.5 {
            statusItem.length = targetLength
        }

        lyricView.update(
            text: display,
            mainLineUTF16: mainLineUTF16,
            timings: timings,
            timeMs: timeMs,
            highlight: prefs.menuBarWordByWord,
            alignment: prefs.menuBarAlignment,
            lineStartMs: lineStartMs,
            lineEndMs: lineEndMs
        )

        let tip = tooltip.joined(separator: "\n")
        if statusItem.button?.toolTip != tip {
            statusItem.button?.toolTip = tip
        }

#if DEBUG
        if debugEnabled, display != lastDebugTitle {
            lastDebugTitle = display
            print("[SPlayerMenuBarLyrics] 菜单栏 -> \(display)")
            fflush(stdout)
        }
#endif
    }

    private func menuBarTargetLength(display: String, maxWidth: CGFloat) -> CGFloat {
        guard prefs.menuBarLyricsEnabled else { return 30 }
        guard prefs.menuBarAutoWidth else {
            return min(CGFloat(prefs.menuBarWidth), maxWidth)
        }
        let key = [
            display,
            "\(prefs.menuBarFontSize)",
            "\(prefs.menuBarWidth)",
            "\(maxWidth)",
            lyricView.layoutSignature,
        ].joined(separator: "|")
        if key != lastAutoWidthKey {
            lastAutoWidthKey = key
            return lyricView.desiredWidth(for: display, maxWidth: maxWidth)
        }
        return statusItem.length
    }

    /// 菜单栏右侧可用宽度；刘海屏上取刘海右侧区域，避免状态项被挤掉
    private func effectiveMaxMenuBarWidth() -> CGFloat {
        let userMax = CGFloat(prefs.menuBarWidth)
        guard let screen = statusItem?.button?.window?.screen ?? NSScreen.main else {
            return userMax
        }
        if let rightArea = screen.auxiliaryTopRightArea, rightArea.width > 0 {
            return min(userMax, max(120, rightArea.width - 12))
        }
        return userMax
    }
}
