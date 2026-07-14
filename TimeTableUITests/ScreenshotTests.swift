import XCTest

/// README용 스크린샷을 캡처하는 테스트.
/// 실행 후 xcresult에서 첨부 이미지를 추출해 docs/screenshots/에 저장한다.
/// (자세한 방법은 README의 스크린샷 갱신 절차 참고)
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureReadmeScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--seed-screenshot-data",
            "-showHolidays", "NO",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
        ]
        app.launch()

        // 1. 시간표 (예약 포함) — 시작 탭
        XCTAssertTrue(app.tabBars.buttons["시간표"].waitForExistence(timeout: 10))
        settle()
        attach(app, name: "01-timetable")

        // 2. 예약 수정 화면 — 시드된 예약 셀 탭
        let cell = app.staticTexts["뽀삐"].firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        XCTAssertTrue(app.navigationBars["예약 수정"].waitForExistence(timeout: 5))
        settle()
        attach(app, name: "02-appointment-form")
        app.navigationBars["예약 수정"].buttons["취소"].tap()

        // 3. 설정 화면
        app.tabBars.buttons["설정"].tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        settle()
        attach(app, name: "03-settings")
    }

    /// 전환 애니메이션이 끝날 때까지 잠시 대기
    private func settle() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.7))
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
