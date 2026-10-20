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
}
