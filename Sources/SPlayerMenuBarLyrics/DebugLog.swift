import Foundation

/// 仅在 DEBUG 构建中启用的日志；Release 下整个实现会被编译掉
enum DebugLog {
    static let enabled: Bool = {
#if DEBUG
        ProcessInfo.processInfo.environment["SPlayerMenuBarLyricsDebug"] == "1"
#else
        false
#endif
    }()

    static func write(_ message: @autoclosure () -> String) {
#if DEBUG
        guard enabled else { return }
        print("[SPlayerMenuBarLyrics] \(message())")
        fflush(stdout)
#endif
    }
}
