import AppKit
import Foundation

/// SPlayer-Next 外部 API 配置
struct SPlayerExternalAPIConfig {
    let enabled: Bool
    let wsEnabled: Bool
    let port: Int
    let path: String
}

/// 读取 SPlayer-Next 自己的配置文件，帮助用户免手填端口
enum SPlayerConfigReader {
    /// SPlayer-Next 在 macOS 上的 bundle id
    static let bundleIdentifier = "top.imsyy.splayer-next"

    private static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// 可能的 userData 目录名：正式版、开发版与带空格的历史命名
    private static var candidatePaths: [URL] {
        let names = ["SPlayer-Next", "splayer-next", "SPlayer Next"]
        return names.map {
            homeDirectory
                .appendingPathComponent("Library/Application Support", isDirectory: true)
                .appendingPathComponent($0, isDirectory: true)
                .appendingPathComponent("app-data/config/settings.json")
        }
    }

    /// 读取 externalApi 配置；找不到有效文件时返回 nil
    static func read() -> SPlayerExternalAPIConfig? {
        for url in candidatePaths {
            guard let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let api = root["externalApi"] as? [String: Any] else { continue }
            let enabled = api["enabled"] as? Bool ?? false
            let wsEnabled = api["wsEnabled"] as? Bool ?? false
            let port = api["port"] as? Int ?? Int(api["port"] as? Double ?? 14558)
            guard port > 0, port < 65536 else { continue }
            return SPlayerExternalAPIConfig(
                enabled: enabled,
                wsEnabled: wsEnabled,
                port: port,
                path: url.path
            )
        }
        return nil
    }

    /// SPlayer-Next 是否正在运行
    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// 唤起已在运行的 SPlayer-Next，否则从常见安装位置启动
    ///
    /// macOS 14 起 `NSRunningApplication.activate(options: .activateIgnoringOtherApps)`
    /// 不再生效，必须交给 LaunchServices（`NSWorkspace.openApplication`）来前置窗口。
    static func activate() {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            ?? fallbackApplicationURL()
        guard let url else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: configuration
        ) { _, _ in }
    }

    private static func fallbackApplicationURL() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "/Applications/SPlayer-Next.app"),
            homeDirectory.appendingPathComponent("Applications/SPlayer-Next.app"),
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }
}
