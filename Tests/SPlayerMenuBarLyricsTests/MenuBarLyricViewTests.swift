import AppKit
import XCTest
@testable import SPlayerMenuBarLyrics

@MainActor
final class MenuBarLyricViewTests: XCTestCase {
    func testLongLyricDrawsOnlyInsideTextArea() throws {
        _ = NSApplication.shared

        let width: CGFloat = 287
        let view = MenuBarLyricView(
            frame: NSRect(x: 0, y: 0, width: width, height: 22)
        )
        view.setControlsVisible(false)
        view.setFavorite(favorite: false, supported: false, available: false)

        let longLine = String(
            repeating: "超宽歌词横向滚动不能盖住右侧控件 ",
            count: 4
        )
        view.update(
            text: longLine,
            mainLineUTF16: longLine.utf16.count,
            timings: [],
            timeMs: 0,
            highlight: false,
            alignment: .left,
            lineStartMs: 0,
            lineEndMs: 10_000
        )
        view.layoutSubtreeIfNeeded()

        // subviews：音符、歌词、上一首、播放、下一首、收藏
        let textView = try XCTUnwrap(view.subviews.dropFirst().first)
        let textMaxX = textView.frame.maxX

        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / view.bounds.width

        var strayPixels = 0
        for y in 0..<rep.pixelsHigh {
            for x in Int(textMaxX * scale)..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.05 {
                    strayPixels += 1
                }
            }
        }
        XCTAssertEqual(strayPixels, 0, "歌词绘制越过了歌词区域右边界")
    }

    func testIconPositionLayout() {
        _ = NSApplication.shared

        let width: CGFloat = 287
        let view = MenuBarLyricView(
            frame: NSRect(x: 0, y: 0, width: width, height: 22)
        )
        view.setControlsVisible(false)
        view.setFavorite(favorite: false, supported: false, available: false)
        view.layoutSubtreeIfNeeded()

        let icon = view.subviews[0]
        let text = view.subviews[1]

        view.setIconPosition(.left)
        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(icon.isHidden)
        XCTAssertEqual(icon.frame.minX, 6)
        XCTAssertEqual(text.frame.minX, 26)

        view.setIconPosition(.right)
        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(icon.isHidden)
        XCTAssertEqual(icon.frame.maxX, width - 6)
        XCTAssertEqual(text.frame.minX, 6)
        XCTAssertEqual(text.frame.maxX, icon.frame.minX - 4)

        view.setIconPosition(.hidden)
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(icon.isHidden)
        XCTAssertEqual(text.frame.minX, 6)
        XCTAssertEqual(text.frame.maxX, width - 6)
    }

    func testDesiredWidthTracksTextLength() {
        _ = NSApplication.shared

        let view = MenuBarLyricView(
            frame: NSRect(x: 0, y: 0, width: 287, height: 22)
        )
        view.setControlsVisible(false)
        view.setFavorite(favorite: false, supported: false, available: false)
        view.setIconPosition(.left)

        let short = view.desiredWidth(for: "短", maxWidth: 600)
        let long = view.desiredWidth(
            for: "这一行歌词明显比上一行长很多很多很多很多很多",
            maxWidth: 600
        )

        XCTAssertGreaterThan(long, short)
        XCTAssertLessThanOrEqual(long, 600)
        XCTAssertGreaterThanOrEqual(short, 60)
    }

    func testDesiredWidthRespectsMaximum() {
        _ = NSApplication.shared

        let view = MenuBarLyricView(
            frame: NSRect(x: 0, y: 0, width: 287, height: 22)
        )
        view.setControlsVisible(true)
        view.setFavorite(favorite: false, supported: true, available: true)

        let wide = view.desiredWidth(
            for: String(repeating: "很长的歌词", count: 50),
            maxWidth: 240
        )
        XCTAssertEqual(wide, 240, accuracy: 0.01)
    }
}
