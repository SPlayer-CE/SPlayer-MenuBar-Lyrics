import XCTest
@testable import SPlayerMenuBarLyrics

final class LyricTimelineTests: XCTestCase {
    private func line(start: Double, end: Double, text: String = "line") -> LyricLine {
        LyricLine(
            words: [LyricWord(word: text, startTime: start, endTime: end)],
            translatedLyric: nil,
            romanLyric: nil,
            startTime: start,
            endTime: end,
            isBG: false,
            isDuet: false
        )
    }

    func testIndexBeforeFirstLine() {
        let timeline = LyricTimeline(lines: [line(start: 1000, end: 2000)])
        XCTAssertEqual(timeline.index(at: 0), -1)
        XCTAssertEqual(timeline.index(at: 999), -1)
    }

    func testIndexSelectsLatestStartedLine() {
        let timeline = LyricTimeline(lines: [
            line(start: 0, end: 1000),
            line(start: 1000, end: 2000),
            line(start: 2000, end: 3000),
        ])
        XCTAssertEqual(timeline.index(at: 0), 0)
        XCTAssertEqual(timeline.index(at: 1500), 1)
        XCTAssertEqual(timeline.index(at: 2000), 2)
        XCTAssertEqual(timeline.index(at: 99999), 2)
    }

    func testBackgroundLinesAreIgnored() {
        let background = LyricLine(
            words: [LyricWord(word: "bg", startTime: 0, endTime: 5000)],
            translatedLyric: nil,
            romanLyric: nil,
            startTime: 0,
            endTime: 5000,
            isBG: true,
            isDuet: false
        )
        let timeline = LyricTimeline(lines: [background, line(start: 1000, end: 2000)])
        XCTAssertEqual(timeline.lines.count, 1)
        XCTAssertEqual(timeline.index(at: 500), -1)
        XCTAssertEqual(timeline.index(at: 1200), 0)
    }
}

final class LyricHighlightTests: XCTestCase {
    func testSingleWordHasNoWordTiming() {
        let line = LyricLine(
            words: [LyricWord(word: "你好世界", startTime: 0, endTime: 4000)],
            translatedLyric: nil,
            romanLyric: nil,
            startTime: 0,
            endTime: 4000,
            isBG: false,
            isDuet: false
        )
        XCTAssertTrue(LyricHighlight.timings(for: line).isEmpty)
    }

    func testRealWordTimingsIncludePreRoll() {
        let line = LyricLine(
            words: [
                LyricWord(word: "ab", startTime: 0, endTime: 1000),
                LyricWord(word: "cd", startTime: 1000, endTime: 3000),
            ],
            translatedLyric: nil,
            romanLyric: nil,
            startTime: 0,
            endTime: 3000,
            isBG: false,
            isDuet: false
        )
        let timings = LyricHighlight.timings(for: line)
        XCTAssertEqual(timings.count, 2)
        XCTAssertEqual(timings[1].utf16Start, 2)
        XCTAssertEqual(timings[1].utf16End, 4)
        // 第二个词原本 1000ms 开始，pre-roll 80ms 后提前到 920ms
        XCTAssertEqual(timings[1].start, 920, accuracy: 0.001)
        XCTAssertEqual(timings[1].end, 3000, accuracy: 0.001)

        let first = LyricHighlight.probe(at: 950, timings: timings)
        XCTAssertEqual(first?.utf16Start, 0)
        XCTAssertEqual(first?.utf16End, 2)
        XCTAssertEqual(first?.fraction ?? -1, 0.95, accuracy: 0.001)

        let second = LyricHighlight.probe(at: 1500, timings: timings)
        XCTAssertEqual(second?.utf16Start, 2)
        XCTAssertEqual(second?.utf16End, 4)
        XCTAssertEqual(second?.fraction ?? -1, 580.0 / 2080.0, accuracy: 0.001)
    }

    func testInvalidWordTimingIsIgnored() {
        let line = LyricLine(
            words: [
                LyricWord(word: "ab", startTime: 0, endTime: 0),
                LyricWord(word: "cd", startTime: 0, endTime: 0),
            ],
            translatedLyric: nil,
            romanLyric: nil,
            startTime: 0,
            endTime: 2000,
            isBG: false,
            isDuet: false
        )
        XCTAssertTrue(LyricHighlight.timings(for: line).isEmpty)
    }

    func testProbeBeforeLineStartReturnsNil() {
        let line = LyricLine(
            words: [
                LyricWord(word: "ab", startTime: 1000, endTime: 1500),
                LyricWord(word: "cd", startTime: 1500, endTime: 2000),
            ],
            translatedLyric: nil,
            romanLyric: nil,
            startTime: 1000,
            endTime: 2000,
            isBG: false,
            isDuet: false
        )
        let timings = LyricHighlight.timings(for: line)
        XCTAssertFalse(timings.isEmpty)
        XCTAssertNil(LyricHighlight.probe(at: 500, timings: timings))
    }
}

final class PositionAnchorTests: XCTestCase {
    func testInterpolatesWhilePlaying() {
        var now = 0.0
        let anchor = PositionAnchor(nowProvider: { now })
        anchor.apply(position: 1000, playing: true, speed: 1, sendTimestamp: nil)
        now = 1
        XCTAssertEqual(anchor.current(), 2000, accuracy: 0.01)
    }

    func testSmallDriftKeepsInterpolation() {
        var now = 0.0
        let anchor = PositionAnchor(nowProvider: { now })
        anchor.apply(position: 1000, playing: true, speed: 1, sendTimestamp: nil)
        now = 2
        anchor.apply(position: 3100, playing: true, speed: 1, sendTimestamp: nil)
        XCTAssertEqual(anchor.current(), 3000, accuracy: 0.01)
    }

    func testLargeDriftRebases() {
        var now = 0.0
        let anchor = PositionAnchor(nowProvider: { now })
        anchor.apply(position: 1000, playing: true, speed: 1, sendTimestamp: nil)
        now = 2
        anchor.apply(position: 5000, playing: true, speed: 1, sendTimestamp: nil)
        XCTAssertEqual(anchor.current(), 5000, accuracy: 0.01)
    }

    func testPauseStopsInterpolation() {
        var now = 0.0
        let anchor = PositionAnchor(nowProvider: { now })
        anchor.apply(position: 1000, playing: true, speed: 1, sendTimestamp: nil)
        now = 1
        anchor.apply(position: 1200, playing: false, speed: 1, sendTimestamp: nil)
        XCTAssertEqual(anchor.current(), 1200, accuracy: 0.01)
        now = 10
        XCTAssertEqual(anchor.current(), 1200, accuracy: 0.01)
    }

    func testSpeedAppliesToInterpolation() {
        var now = 0.0
        let anchor = PositionAnchor(nowProvider: { now })
        anchor.apply(position: 0, playing: true, speed: 1.5, sendTimestamp: nil)
        now = 2
        XCTAssertEqual(anchor.current(), 3000, accuracy: 0.01)
    }
}
