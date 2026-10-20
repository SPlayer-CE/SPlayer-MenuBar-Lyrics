import Combine
import Foundation

/// 通过 GitHub Releases 检查新版本，不引入 Sparkle
@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate(String)
        case available(version: String, url: URL)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let repository = "SPlayer-CE/SPlayer-MenuBar-Lyrics"
    private let lastCheckKey = "lastUpdateCheck"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"
    }

    /// 启动时最多每 24 小时静默检查一次
    func autoCheckIfNeeded() async {
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 24 * 60 * 60 else { return }
        await check()
    }

    func check() async {
        guard state != .checking else { return }
        state = .checking
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)

        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            state = .failed(L10n.t(.updateCheckFailed))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(
            "SPlayerMenuBarLyrics/\(Self.currentVersion)",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                state = .failed(L10n.t(.updateCheckFailed))
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tagName
                .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let page = URL(string: release.htmlURL) ?? url
            if Self.isNewer(latest, than: Self.currentVersion) {
                state = .available(version: latest, url: page)
            } else {
                state = .upToDate(latest)
            }
        } catch {
            state = .failed(L10n.format(.updateCheckFailedDetail, error.localizedDescription))
        }
    }

    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
}
