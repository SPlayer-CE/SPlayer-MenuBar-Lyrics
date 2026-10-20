import Combine
import Foundation

/// 与 SPlayer-Next 外部 API 的连接状态
enum SPlayerConnectionStatus: Equatable {
    case connecting
    case connected
    case disabled
    case unreachable

    var title: String {
        switch self {
        case .connecting: return L10n.t(.statusConnecting)
        case .connected: return L10n.t(.statusConnected)
        case .disabled: return L10n.t(.statusApiOff)
        case .unreachable: return L10n.t(.statusUnreachable)
        }
    }
}

/// 轮询 + WebSocket 的 SPlayer-Next 客户端
///
/// 位置属于高频数据，外部 WebSocket 不会推送，因此始终以固定频率轮询
/// `/api/now-playing` 取锚点；WebSocket 只用来让切歌和歌词变化即时到达。
@MainActor
final class SPlayerClient: ObservableObject {
    @Published private(set) var status: SPlayerConnectionStatus = .connecting {
        didSet {
            if status != oldValue {
                debugLog("status -> \(status.title) \(statusDetail)")
            }
        }
    }
    @Published private(set) var statusDetail = ""
    @Published private(set) var track: Track?
    @Published private(set) var lyrics: [LyricLine] = []
    @Published private(set) var timeline = LyricTimeline(lines: [])
    @Published private(set) var lyricOffsetMs: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var playbackState = "idle"
    @Published private(set) var speed: Double = 1
    @Published private(set) var wsConnected = false
    @Published private(set) var serverVersion: String?

    let anchor = PositionAnchor()

    private let prefs: Preferences
    private var pollTask: Task<Void, Never>?
    private var wsTask: Task<Void, Never>?
    private var wsSocket: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private var lyricTask: Task<Void, Never>?
    private var lyricFetchInFlight = false
    private var lyricFetchGeneration = 0
    private var lastLyricFetchTrackID: String?
    private var lastLyricLineCount = -1

    /// 轮询间隔（秒）
    private let connectedPollInterval: Double = 0.45
    private let disconnectedPollInterval: Double = 2.0

    init(prefs: Preferences) {
        self.prefs = prefs
    }

    deinit {
        pollTask?.cancel()
        wsTask?.cancel()
        lyricTask?.cancel()
    }

    /// 当前用于歌词索引的时间（毫秒，已叠加 SPlayer-Next 的偏移与用户微调）
    var currentLyricTimeMs: Double {
        anchor.current() + lyricOffsetMs + prefs.userLyricOffsetMs
    }

    /// 当前播放位置（毫秒，不含歌词偏移）
    var currentPositionMs: Double {
        max(0, anchor.current())
    }

    var statusText: String {
        switch status {
        case .connecting:
            return L10n.t(.statusConnectingSPlayer)
        case .connected:
            if track == nil { return L10n.t(.statusConnectedIdle) }
            return L10n.t(isPlaying ? .statusConnectedPlaying : .statusConnectedPaused)
        case .disabled:
            return L10n.t(.statusApiOff)
        case .unreachable:
            return statusDetail.isEmpty
                ? L10n.t(.statusUnreachablePlayer)
                : L10n.format(.statusUnreachableDetail, statusDetail)
        }
    }

    /// 曲目/歌手显示文本
    var songInfoText: String {
        guard let track else { return "" }
        return "\(track.title) — \(track.artistsText)"
    }

    func start() {
        prefs.$port
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.restart() }
            }
            .store(in: &cancellables)
        restart()
    }

    /// 重启所有连接（端口变化 / 手动重连）
    func restart() {
        pollTask?.cancel()
        wsTask?.cancel()
        lyricTask?.cancel()
        wsSocket?.cancel(with: .goingAway, reason: nil)
        wsSocket = nil
        lyricFetchInFlight = false
        lastLyricFetchTrackID = nil
        lastLyricLineCount = -1
        wsConnected = false
        serverVersion = nil
        anchor.reset()
        if status != .connecting {
            status = .connecting
        }
        if !statusDetail.isEmpty {
            statusDetail = ""
        }

        pollTask = Task { @MainActor [weak self] in
            await self?.pollLoop()
        }
        wsTask = Task { @MainActor [weak self] in
            await self?.webSocketLoop()
        }
        fetchServerInfo()
    }

    /// 手动拉取一次歌词
    func refreshLyrics() {
        fetchLyrics(force: true)
    }

    /// 播放 / 暂停
    func togglePlayback() {
        post(isPlaying ? "/api/pause" : "/api/play")
    }

    /// 下一曲
    func nextTrack() {
        post("/api/next")
    }

    /// 上一曲
    func previousTrack() {
        post("/api/prev")
    }

    private func post(_ path: String) {
        guard let url = URL(string: "http://127.0.0.1:\(prefs.port)\(path)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        Task { @MainActor [weak self] in
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    self?.debugLog("控制命令失败: \(path)")
                    return
                }
            } catch {
                self?.debugLog("控制命令失败: \(path) \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 轮询

    private func pollLoop() async {
        while !Task.isCancelled {
            let interval = await pollOnce()
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return
            }
        }
    }

    /// 执行一次轮询
    /// - Returns: 下一次轮询的等待秒数
    private func pollOnce() async -> Double {
        guard let url = URL(string: "http://127.0.0.1:\(prefs.port)/api/now-playing") else {
            setStatus(.disabled, detail: L10n.t(.invalidPort))
            return disconnectedPollInterval
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                setStatus(.unreachable, detail: L10n.t(.invalidResponse))
                return disconnectedPollInterval
            }
            switch http.statusCode {
            case 200..<300:
                let snapshot = try JSONDecoder().decode(NowPlaying.self, from: data)
                apply(snapshot: snapshot)
                return connectedPollInterval
            case 403:
                setStatus(.disabled, detail: L10n.t(.enableApiHint))
                return disconnectedPollInterval
            default:
                setStatus(.unreachable, detail: "HTTP \(http.statusCode)")
                return disconnectedPollInterval
            }
        } catch {
            setStatus(.unreachable, detail: friendlyError(error))
            return disconnectedPollInterval
        }
    }

    private func apply(snapshot: NowPlaying) {
        if status != .connected {
            status = .connected
        }
        if !statusDetail.isEmpty {
            statusDetail = ""
        }
        applyTrack(snapshot.track)
        if isPlaying != snapshot.playing {
            isPlaying = snapshot.playing
        }
        if playbackState != snapshot.state {
            playbackState = snapshot.state
        }
        if speed != snapshot.speed {
            speed = snapshot.speed
        }
        if lyricOffsetMs != snapshot.lyricOffsetMs {
            lyricOffsetMs = snapshot.lyricOffsetMs
        }
        anchor.apply(
            position: snapshot.position,
            playing: snapshot.playing,
            speed: snapshot.speed,
            sendTimestamp: snapshot.sendTimestamp
        )

        if snapshot.lyricAvailable,
           let track,
           lastLyricFetchTrackID != track.id || lastLyricLineCount != snapshot.lyricLineCount {
            fetchLyrics(force: false)
        }
    }

    // MARK: - WebSocket

    private func webSocketLoop() async {
        var backoff: Double = 1
        while !Task.isCancelled {
            guard let url = URL(string: "ws://127.0.0.1:\(prefs.port)/ws") else {
                return
            }
            let socket = URLSession.shared.webSocketTask(with: url)
            wsSocket = socket
            socket.resume()

            do {
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    switch message {
                    case .string(let text):
                        handleWebSocketMessage(text)
                    case .data(let data):
                        handleWebSocketMessage(String(decoding: data, as: UTF8.self))
                    @unknown default:
                        break
                    }
                }
            } catch {
                wsConnected = false
                socket.cancel(with: .goingAway, reason: nil)
                if wsSocket === socket { wsSocket = nil }
                if Task.isCancelled { return }
                do {
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                } catch {
                    return
                }
                backoff = min(backoff * 1.5, 10)
            }
        }
    }

    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = object["kind"] as? String else { return }

        if kind == "hello" {
            wsConnected = true
            debugLog("WebSocket 已连接")
            return
        }
        guard kind == "event", let type = object["type"] as? String else { return }

        let dataObject = object["data"]
        let dataData: Data? = {
            guard let dataObject,
                  JSONSerialization.isValidJSONObject(dataObject) else { return nil }
            return try? JSONSerialization.data(withJSONObject: dataObject)
        }()
        let decoder = JSONDecoder()

        switch type {
        case "track":
            if let dataData,
               let event = try? decoder.decode(TrackEvent.self, from: dataData) {
                applyTrack(event.track)
            }
        case "lyric":
            if let dataData,
               let event = try? decoder.decode(LyricEvent.self, from: dataData) {
                applyLyrics(event.lyric, trackID: track?.id)
            }
        case "lyricOffset":
            if let dataData,
               let event = try? decoder.decode(LyricOffsetEvent.self, from: dataData) {
                lyricOffsetMs = event.offsetMs
            }
        case "status":
            if let dataData,
               let event = try? decoder.decode(PlaybackStatusEvent.self, from: dataData) {
                playbackState = event.state
                isPlaying = event.state == "playing"
                speed = event.speed ?? speed
                anchor.apply(
                    position: event.position,
                    playing: isPlaying,
                    speed: event.speed ?? speed,
                    sendTimestamp: nil
                )
            }
        case "ended", "sourceError":
            isPlaying = false
            if type == "ended" { playbackState = "stopped" }
        default:
            break
        }
    }

    // MARK: - 曲目与歌词

    private func applyTrack(_ next: Track?) {
        let previousID = track?.id
        guard previousID != next?.id else { return }
        debugLog("曲目切换 -> \(next?.title ?? "nil")")
        track = next
        lyricOffsetMs = 0
        lastLyricFetchTrackID = nil
        lastLyricLineCount = -1
        applyLyrics([], trackID: next?.id)
        anchor.reset()
        if next != nil {
            fetchLyrics(force: true)
        }
    }

    private func applyLyrics(_ lines: [LyricLine], trackID: String?) {
        if lyrics != lines {
            lyrics = lines
            timeline = LyricTimeline(lines: lines)
        }
        lastLyricLineCount = lines.filter { !$0.isBackground }.count
        if let trackID {
            lastLyricFetchTrackID = trackID
        }
        debugLog("歌词更新 -> \(timeline.lines.count) 行")
    }

    private func fetchLyrics(force: Bool) {
        guard let track else { return }
        if lyricFetchInFlight && !force { return }
        lyricFetchInFlight = true
        lyricFetchGeneration += 1
        let generation = lyricFetchGeneration
        lyricTask?.cancel()
        let expectedTrackID = track.id

        lyricTask = Task { @MainActor [weak self] in
            defer {
                if let self, self.lyricFetchGeneration == generation {
                    self.lyricFetchInFlight = false
                }
            }
            for attempt in 0..<3 {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                do {
                    let snapshot: LyricSnapshot = try await self.getJSON("/api/lyrics")
                    guard self.lyricFetchGeneration == generation,
                          self.track?.id == expectedTrackID else { return }
                    if let returnedID = snapshot.trackId,
                       let currentID = self.track?.id,
                       returnedID != currentID {
                        // 渲染端还没提交新曲歌词，稍后再取
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        continue
                    }
                    if Task.isCancelled { return }
                    self.lyrics = snapshot.lyric
                    self.timeline = LyricTimeline(lines: snapshot.lyric)
                    if let offset = snapshot.lyricOffsetMs {
                        self.lyricOffsetMs = offset
                    }
                    self.lastLyricFetchTrackID = expectedTrackID
                    self.lastLyricLineCount = snapshot.lyric.filter { !$0.isBackground }.count
                    return
                } catch {
                    if attempt == 2 { return }
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        }
    }

    private func fetchServerInfo() {
        guard let url = URL(string: "http://127.0.0.1:\(prefs.port)/api/info") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData
        Task { @MainActor [weak self] in
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let info = try? JSONDecoder().decode(SPlayerInfo.self, from: data) else {
                return
            }
            self?.serverVersion = info.version
        }
    }

    private func getJSON<T: Decodable>(_ path: String) async throws -> T {        guard let url = URL(string: "http://127.0.0.1:\(prefs.port)\(path)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func setStatus(_ next: SPlayerConnectionStatus, detail: String) {
        if statusDetail != detail {
            statusDetail = detail
        }
        if status != next {
            status = next
        }
    }

    private func friendlyError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                return L10n.t(.playerNotRunning)
            case .timedOut:
                return L10n.t(.connectionTimedOut)
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        DebugLog.write(message())
#endif
    }
}
