import Foundation

/// 播放位置锚点
///
/// 外部 API 只提供离散的位置采样，这里用系统单调时钟在采样之间插值，
/// 并对偏差过大的采样重新锚定，避免网络抖动造成歌词跳动。
final class PositionAnchor {
    private var positionMs: Double = 0
    private var uptime: Double = 0
    private var speed: Double = 1
    private var playing = false
    private var initialized = false

    private let nowProvider: () -> Double

    /// - Parameter nowProvider: 单调时钟（秒），测试中可注入
    init(nowProvider: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.nowProvider = nowProvider
    }

    /// 当前歌词时间（毫秒）
    func current() -> Double {
        guard initialized else { return 0 }
        guard playing else { return positionMs }
        return positionMs + (nowProvider() - uptime) * 1000 * speed
    }

    /// 用一次采样校正锚点
    /// - Parameters:
    ///   - position: 采样时的播放位置（毫秒）
    ///   - playing: 是否正在播放
    ///   - speed: 播放倍率
    ///   - sendTimestamp: 采样成立时的墙钟毫秒（Date.now），用于补偿传输延迟
    func apply(position: Double, playing: Bool, speed: Double, sendTimestamp: Double?) {
        let now = nowProvider()
        let projected = current()
        let delayMs: Double
        if let sendTimestamp, sendTimestamp > 0 {
            let wallNow = Date().timeIntervalSince1970 * 1000
            delayMs = min(max(wallNow - sendTimestamp, 0), 1000)
        } else {
            delayMs = 0
        }
        let candidate = position + (playing ? delayMs * speed : 0)

        if !initialized || playing != self.playing || abs(candidate - projected) > 300 {
            positionMs = candidate
            uptime = now
        } else {
            positionMs = projected
            uptime = now
        }
        self.speed = max(0.1, speed)
        self.playing = playing
        initialized = true
    }

    /// 清空（停止播放 / 断开连接）
    func reset() {
        positionMs = 0
        uptime = nowProvider()
        speed = 1
        playing = false
        initialized = false
    }
}

/// 歌词时间轴：负责从非背景行里选出当前行
struct LyricTimeline {
    let lines: [LyricLine]

    init(lines: [LyricLine]) {
        self.lines = lines.filter { !$0.isBackground }
    }

    /// 当前行索引；早于第一行时为 -1
    func index(at timeMs: Double) -> Int {
        guard !lines.isEmpty else { return -1 }
        var result = -1
        for (index, line) in lines.enumerated() {
            if line.startTime <= timeMs {
                result = index
            } else {
                break
            }
        }
        return result
    }
}
