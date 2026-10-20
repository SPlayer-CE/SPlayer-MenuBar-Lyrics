import Foundation

/// 一个歌词词块在整行文本中的 UTF-16 范围与（已应用 pre-roll 的）时间区间
struct CharacterTiming: Equatable {
    let utf16Start: Int
    let utf16End: Int
    let start: Double
    let end: Double
}

/// 某一时刻的高亮探针
struct HighlightProbe: Equatable {
    let utf16Start: Int
    let utf16End: Int
    /// 当前词块内部已播放的比例
    let fraction: Double
}

/// 与 lyric-kit 的 `getWordSweepProgress` 对齐的逐字时间轴
enum LyricHighlight {
    /// 为一行歌词生成词块级时间片
    ///
    /// SPlayer 的逐字进度不是按字符均分，而是直接使用歌词文件里的 word 时间，
    /// 并把每个词的起点提前 min(80ms, 词长 30%)，让扫光略微提前进入，观感更顺。
    /// 只有歌词本身带多个 word 且时间有效时才返回时间片；LRC 这类整行歌词
    /// 没有逐字时间，保持静态显示，不做任何自动生成。
    /// - Parameter line: 歌词行
    /// - Returns: 与 `line.text` 的 UTF-16 范围对应的词块时间片
    static func timings(for line: LyricLine) -> [CharacterTiming] {
        let words = line.words.filter { !$0.word.isEmpty }
        guard words.count > 1,
              words.allSatisfy({ $0.endTime > $0.startTime }) else {
            return []
        }

        var spans: [CharacterTiming] = []
        var offset = 0
        for word in words {
            let length = word.word.utf16.count
            guard length > 0 else { continue }
            let duration = word.endTime - word.startTime
            let preRoll = min(80, duration * 0.3)
            let adjustedStart = max(line.startTime, word.startTime - preRoll)
            spans.append(
                CharacterTiming(
                    utf16Start: offset,
                    utf16End: offset + length,
                    start: adjustedStart,
                    end: word.endTime
                )
            )
            offset += length
        }

        guard offset == line.text.utf16.count else { return [] }
        return spans
    }

    /// 查询指定时刻的高亮位置；早于整行开始时返回 nil
    static func probe(at timeMs: Double, timings: [CharacterTiming]) -> HighlightProbe? {
        guard let first = timings.first, let last = timings.last else { return nil }
        if timeMs < first.start { return nil }
        if timeMs >= last.end {
            return HighlightProbe(utf16Start: last.utf16End, utf16End: last.utf16End, fraction: 0)
        }
        for timing in timings {
            if timeMs < timing.start {
                return HighlightProbe(
                    utf16Start: timing.utf16Start,
                    utf16End: timing.utf16Start,
                    fraction: 0
                )
            }
            if timeMs <= timing.end {
                let duration = max(timing.end - timing.start, 1)
                let fraction = min(max((timeMs - timing.start) / duration, 0), 1)
                return HighlightProbe(
                    utf16Start: timing.utf16Start,
                    utf16End: timing.utf16End,
                    fraction: fraction
                )
            }
        }
        return HighlightProbe(utf16Start: last.utf16End, utf16End: last.utf16End, fraction: 0)
    }
}
