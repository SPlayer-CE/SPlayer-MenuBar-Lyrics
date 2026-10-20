import XCTest
@testable import SPlayerMenuBarLyrics

final class LocalizationTests: XCTestCase {
    override func tearDown() {
        L10n.language = .system
        super.tearDown()
    }

    func testEveryKeyHasBothTranslations() {
        for key in L10nKey.allCases {
            XCTAssertNotNil(L10n.chinese[key], "缺少中文文案：\(key)")
            XCTAssertNotNil(L10n.english[key], "缺少英文文案：\(key)")
        }
    }

    func testLanguageSwitchesStrings() {
        L10n.language = .chinese
        XCTAssertEqual(L10n.t(.play), "播放")
        L10n.language = .english
        XCTAssertEqual(L10n.t(.play), "Play")
    }

    func testFormatSubstitutesArguments() {
        L10n.language = .english
        XCTAssertEqual(
            L10n.format(.statusUnreachableDetail, "timeout"),
            "Unable to connect · timeout"
        )
        XCTAssertEqual(L10n.format(.configPortOK, 14558), "Port 14558 loaded: configuration looks good")
    }

    func testLanguageDisplayNamesAreLocalized() {
        L10n.language = .chinese
        XCTAssertEqual(AppLanguage.system.displayName, "跟随系统")
        L10n.language = .english
        XCTAssertEqual(AppLanguage.system.displayName, "System")
        XCTAssertEqual(AppLanguage.chinese.displayName, "简体中文")
    }
}
