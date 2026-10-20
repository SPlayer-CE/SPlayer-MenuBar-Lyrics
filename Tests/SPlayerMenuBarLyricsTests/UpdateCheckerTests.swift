import XCTest
@testable import SPlayerMenuBarLyrics

final class UpdateCheckerTests: XCTestCase {
    func testNumericVersionComparison() {
        XCTAssertTrue(UpdateChecker.isNewer("1.2.0", than: "1.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("1.10.0", than: "1.9.9"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0.0", than: "1.99.99"))
        XCTAssertFalse(UpdateChecker.isNewer("1.1.0", than: "1.1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.9", than: "1.1.0"))
    }

    func testNightlyVersionComparison() {
        XCTAssertTrue(
            UpdateChecker.isNewer("1.2.0-nightly.991", than: "1.2.0-nightly.990")
        )
        XCTAssertFalse(
            UpdateChecker.isNewer("1.2.0-nightly.990", than: "1.2.0-nightly.990")
        )
    }
}
