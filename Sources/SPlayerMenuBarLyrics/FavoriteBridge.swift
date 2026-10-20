import Foundation
import Network

/// 插件上报的收藏状态
struct FavoriteReport: Equatable {
    let trackId: String
    let favorite: Bool
    let source: String
    let available: Bool
}

/// 等待插件执行的收藏切换请求
struct FavoriteToggleRequest {
    let trackId: String
    let favorite: Bool
    let createdAt: Date
}

/// 菜单栏应用与 SPlayer 插件之间的本地 HTTP 桥接
///
/// 插件在 SPlayer 沙箱里无法主动通知外部进程，因此由本应用提供
/// `127.0.0.1:14561` 上的极简 HTTP 接口：
/// - `GET /toggle` 插件轮询待处理的收藏切换
/// - `POST /state` 插件回报当前曲目的收藏状态
/// - `GET /state` 调试用
@MainActor
final class FavoriteBridge: ObservableObject {
    @Published private(set) var revision = 0
    @Published private(set) var pluginConnected = false
    @Published private(set) var listening = false

    private let server: FavoriteBridgeServer
    private var favorites: [String: Bool] = [:]
    private var availability: [String: Bool] = [:]
    private var order: [String] = []
    private var connectionTimer: Timer?

    init(port: UInt16 = 14561) {
        server = FavoriteBridgeServer(port: port)
        server.onState = { [weak self] report in
            DispatchQueue.main.async {
                self?.apply(report)
            }
        }
        server.onListening = { [weak self] listening in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.listening != listening {
                    self.listening = listening
                    self.revision += 1
                }
            }
        }
        server.start()

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkConnection()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        connectionTimer = timer
    }

    /// 当前曲目的收藏状态；nil 表示插件尚未回报
    func favorite(for trackId: String) -> Bool? {
        favorites[trackId]
    }

    /// 当前曲目是否支持收藏（插件是否登录/来源是否支持）
    func available(for trackId: String) -> Bool? {
        availability[trackId]
    }

    /// 请求切换收藏，插件下一次轮询时执行
    func requestToggle(trackId: String, favorite: Bool) {
        favorites[trackId] = favorite
        remember(trackId)
        revision += 1
        server.setPending(
            FavoriteToggleRequest(trackId: trackId, favorite: favorite, createdAt: Date())
        )
    }

    /// 手动刷新：重启桥接端口（若已停止），并让插件立即重新上报状态
    func refresh() {
        if !listening {
            server.restart()
        }
        server.requestRefresh()
        updateConnection()
        if ProcessInfo.processInfo.environment["SPlayerMenuBarLyricsDebug"] == "1" {
            print("[SPlayerMenuBarLyrics] 刷新收藏插件连接 listening=\(listening)")
            fflush(stdout)
        }
    }

    private func apply(_ report: FavoriteReport) {
        if ProcessInfo.processInfo.environment["SPlayerMenuBarLyricsDebug"] == "1" {
            print(
                "[SPlayerMenuBarLyrics] 收藏状态 track=\(report.trackId) favorite=\(report.favorite) available=\(report.available)"
            )
            fflush(stdout)
        }
        favorites[report.trackId] = report.favorite
        availability[report.trackId] = report.available
        remember(report.trackId)
        if !pluginConnected {
            pluginConnected = true
        }
        revision += 1
    }

    private func remember(_ trackId: String) {
        order.removeAll { $0 == trackId }
        order.append(trackId)
        while order.count > 300 {
            let evicted = order.removeFirst()
            favorites.removeValue(forKey: evicted)
            availability.removeValue(forKey: evicted)
        }
    }

    private func checkConnection() {
        updateConnection()
    }

    /// 插件每 400ms 轮询一次 `/toggle`，只要近期有请求就算在线
    private func updateConnection() {
        let last = server.lastContact()
        let connected = last.map { Date().timeIntervalSince($0) < 3 } ?? false
        if pluginConnected != connected {
            pluginConnected = connected
            revision += 1
            // 插件刚连上（应用启动或插件重载）时主动要一次状态，免得红心先空着
            if connected {
                server.requestRefresh()
            }
        }
    }
}

/// 桥接 HTTP 服务，只绑定 127.0.0.1
final class FavoriteBridgeServer {
    var onState: ((FavoriteReport) -> Void)?
    var onListening: ((Bool) -> Void)?

    private let port: UInt16
    private let queue = DispatchQueue(label: "com.beichen.SPlayerMenuBarLyrics.favorite-bridge")
    private let lock = NSLock()
    private var listener: NWListener?
    private var pending: FavoriteToggleRequest?
    private var lastReport: FavoriteReport?
    private var lastContactAt: Date?
    private var refreshRequested = false

    init(port: UInt16) {
        self.port = port
    }

    /// 插件最近一次访问桥接的时间
    func lastContact() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return lastContactAt
    }

    /// 下一次插件轮询时要求它重新上报当前曲目状态
    func requestRefresh() {
        lock.lock()
        refreshRequested = true
        lock.unlock()
        log("请求插件重新上报")
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let parameters = NWParameters.tcp
                guard let nwPort = NWEndpoint.Port(rawValue: self.port) else { return }
                parameters.requiredLocalEndpoint = .hostPort(
                    host: .ipv4(.loopback),
                    port: nwPort
                )
                let listener = try NWListener(using: parameters)
                listener.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        self?.log("桥接服务已启动 127.0.0.1:\(self?.port ?? 0)")
                        self?.onListening?(true)
                    case .failed(let error):
                        self?.log("桥接服务启动失败: \(error)")
                        self?.onListening?(false)
                    case .cancelled:
                        self?.onListening?(false)
                    default:
                        break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    self?.handle(connection)
                }
                listener.start(queue: self.queue)
                self.listener = listener
            } catch {
                self.log("桥接服务创建失败: \(error)")
                self.onListening?(false)
            }
        }
    }

    func restart() {
        queue.async { [weak self] in
            guard let self else { return }
            let existing = self.listener
            self.listener = nil
            existing?.cancel()
            if existing != nil {
                // 让系统先释放端口，再重建监听
                self.queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.start()
                }
            } else {
                self.start()
            }
        }
    }

    func setPending(_ request: FavoriteToggleRequest) {
        lock.lock()
        pending = request
        lock.unlock()
    }

    private func takePending() -> FavoriteToggleRequest? {
        lock.lock()
        defer { lock.unlock() }
        guard let request = pending else { return nil }
        pending = nil
        guard Date().timeIntervalSince(request.createdAt) <= 10 else { return nil }
        return request
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var accumulated = buffer
            if let data, !data.isEmpty {
                accumulated.append(data)
            }
            if accumulated.count > 65536 {
                connection.cancel()
                return
            }
            if let request = Self.parse(accumulated) {
                self.route(request, connection: connection)
                return
            }
            if !isComplete, error == nil {
                self.receive(connection, buffer: accumulated)
            } else {
                connection.cancel()
            }
        }
    }

    private func route(_ request: HTTPRequest, connection: NWConnection) {
        let path = request.path.split(separator: "?").first.map(String.init) ?? request.path
        lock.lock()
        lastContactAt = Date()
        lock.unlock()

        switch (request.method, path) {
        case ("GET", "/ping"):
            respond(["ok": true, "version": 1], to: connection)
        case ("GET", "/toggle"):
            lock.lock()
            let shouldRefresh = refreshRequested
            refreshRequested = false
            lock.unlock()
            if shouldRefresh {
                log("插件已收到刷新请求")
            }
            if let pending = takePending() {
                respond(
                    [
                        "pending": true,
                        "trackId": pending.trackId,
                        "favorite": pending.favorite,
                        "requestedAt": pending.createdAt.timeIntervalSince1970 * 1000,
                        "refresh": shouldRefresh,
                    ],
                    to: connection
                )
            } else if shouldRefresh {
                respond(["pending": false, "refresh": true], to: connection)
            } else {
                respond(["pending": false], to: connection)
            }
        case ("POST", "/state"):
            handleState(request.body, connection: connection)
        case ("GET", "/state"):
            lock.lock()
            let report = lastReport
            lock.unlock()
            if let report {
                respond(
                    [
                        "trackId": report.trackId,
                        "favorite": report.favorite,
                        "source": report.source,
                        "available": report.available,
                    ],
                    to: connection
                )
            } else {
                respond(["trackId": NSNull()], to: connection)
            }
        default:
            respond(["ok": false, "error": "not found"], to: connection, status: "404 Not Found")
        }
    }

    private func handleState(_ body: Data, connection: NWConnection) {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let trackId = object["trackId"] as? String, !trackId.isEmpty,
              let favorite = object["favorite"] as? Bool else {
            respond(["ok": false, "error": "invalid payload"], to: connection)
            return
        }
        let report = FavoriteReport(
            trackId: trackId,
            favorite: favorite,
            source: object["source"] as? String ?? "",
            available: object["available"] as? Bool ?? false
        )
        lock.lock()
        lastReport = report
        lock.unlock()
        onState?(report)
        respond(["ok": true], to: connection)
    }

    private func respond(
        _ object: [String: Any],
        to connection: NWConnection,
        status: String = "200 OK"
    ) {
        guard JSONSerialization.isValidJSONObject(object),
              let body = try? JSONSerialization.data(withJSONObject: object) else {
            connection.cancel()
            return
        }
        let header = "HTTP/1.1 \(status)\r\n"
            + "Content-Type: application/json; charset=utf-8\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func log(_ message: String) {
        guard ProcessInfo.processInfo.environment["SPlayerMenuBarLyricsDebug"] == "1" else {
            return
        }
        print("[SPlayerMenuBarLyrics] \(message)")
        fflush(stdout)
    }

    private struct HTTPRequest {
        let method: String
        let path: String
        let body: Data
    }

    /// 解析请求；数据不完整时返回 nil，由调用方继续接收
    private static func parse(_ data: Data) -> HTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator) else { return nil }
        guard let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            return nil
        }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var contentLength = 0
        for line in lines.dropFirst() {
            let lower = line.lowercased()
            guard lower.hasPrefix("content-length:") else { continue }
            let value = line.dropFirst("content-length:".count)
                .trimmingCharacters(in: .whitespaces)
            contentLength = Int(value) ?? 0
        }

        let bodyStart = headerRange.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }
        let body = data[bodyStart..<(bodyStart + contentLength)]
        return HTTPRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            body: Data(body)
        )
    }
}
