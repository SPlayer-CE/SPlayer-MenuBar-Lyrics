import AppKit
import Foundation

/// 收集可公开的排障信息，方便用户附在 issue 里
@MainActor
enum Diagnostics {
    static func text(
        prefs: Preferences,
        client: SPlayerClient,
        favoriteBridge: FavoriteBridge
    ) -> String {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "dev"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev"
        let process = ProcessInfo.processInfo

        var lines: [String] = []
        lines.append("SPlayer Menu Bar Lyrics \(appVersion) (\(build))")
        lines.append("macOS \(process.operatingSystemVersionString)")
        lines.append("Arch: \(arch)")
        lines.append("Language: \(prefs.language.rawValue)")
        lines.append("")

        lines.append("[Connection]")
        lines.append("status: \(client.status.title)")
        lines.append("detail: \(client.statusDetail)")
        lines.append("port: \(prefs.port)")
        lines.append("websocket: \(client.wsConnected)")
        lines.append("splayer-next: \(client.serverVersion ?? "unknown")")
        lines.append("")

        lines.append("[Playback]")
        lines.append("playing: \(client.isPlaying)")
        lines.append("state: \(client.playbackState)")
        lines.append("track: \(client.track?.title ?? "-")")
        lines.append("artist: \(client.track?.artistsText ?? "-")")
        lines.append("source: \(client.track?.source ?? "-")")
        lines.append("lyrics: \(client.timeline.lines.count) lines")
        lines.append(
            "offset: \(Int(client.lyricOffsetMs))ms + user \(Int(prefs.userLyricOffsetMs))ms"
        )
        lines.append("")

        lines.append("[Menu bar]")
        lines.append(
            "width: \(Int(prefs.menuBarWidth))px auto=\(prefs.menuBarAutoWidth) font=\(Int(prefs.menuBarFontSize))pt"
        )
        lines.append("alignment: \(prefs.menuBarAlignment.rawValue)")
        lines.append("icon: \(prefs.menuBarIconPosition.rawValue)")
        lines.append("always show controls: \(prefs.menuBarAlwaysVisible)")
        lines.append("")

        lines.append("[Favorite bridge]")
        lines.append("listening: \(favoriteBridge.listening)")
        lines.append("plugin connected: \(favoriteBridge.pluginConnected)")

        if let screen = NSApp.keyWindow?.screen ?? NSScreen.main {
            lines.append("")
            lines.append("[Screen]")
            lines.append("name: \(screen.localizedName)")
            lines.append("size: \(Int(screen.frame.width))x\(Int(screen.frame.height))")
            lines.append("top safe area: \(Int(screen.safeAreaInsets.top))")
            if let rightArea = screen.auxiliaryTopRightArea, rightArea.width > 0 {
                lines.append("menu bar right area: \(Int(rightArea.width))px")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static var arch: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
