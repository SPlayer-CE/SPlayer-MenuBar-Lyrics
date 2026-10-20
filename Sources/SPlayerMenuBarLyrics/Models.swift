import Foundation

/// SPlayer-Next 曲目歌手
struct Artist: Decodable, Equatable {
    let name: String
}

/// SPlayer-Next 曲目（只解码歌词显示需要的字段）
struct Track: Decodable, Equatable {
    let id: String
    /// 曲目来源（netease / qqmusic / kugou / local / streaming ...）
    let source: String?
    let title: String
    let artists: [Artist]?
    let duration: Double?

    var artistsText: String {
        let names = (artists ?? []).map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? L10n.t(.unknownArtist) : names.joined(separator: " / ")
    }
}

/// 逐字歌词中的单个片段
struct LyricWord: Decodable, Equatable {
    let word: String
    let startTime: Double
    let endTime: Double
}

/// SPlayer-Next 解析后的歌词行
struct LyricLine: Decodable, Equatable {
    let words: [LyricWord]
    let translatedLyric: String?
    let romanLyric: String?
    let startTime: Double
    let endTime: Double
    let isBG: Bool?
    let isDuet: Bool?

    var text: String {
        words.map(\.word).joined()
    }

    var isBackground: Bool {
        isBG ?? false
    }
}

/// GET /api/now-playing
struct NowPlaying: Decodable {
    let track: Track?
    let position: Double
    let playing: Bool
    let state: String
    let speed: Double
    let lyricOffsetMs: Double
    let lyricAvailable: Bool
    let lyricLineCount: Int
    let sendTimestamp: Double
}

/// GET /api/lyrics
struct LyricSnapshot: Decodable {
    let trackId: String?
    let lyric: [LyricLine]
    let lyricOffsetMs: Double?
}

/// WebSocket 播放状态事件（type=status）
struct PlaybackStatusEvent: Decodable {
    let state: String
    let position: Double
    let duration: Double?
    let volume: Double?
    let speed: Double?
}

/// WebSocket 曲目切换事件（type=track）
struct TrackEvent: Decodable {
    let track: Track?
}

/// WebSocket 歌词变更事件（type=lyric）
struct LyricEvent: Decodable {
    let lyric: [LyricLine]
}

/// WebSocket 歌词偏移事件（type=lyricOffset）
struct LyricOffsetEvent: Decodable {
    let trackId: String?
    let offsetMs: Double
}
