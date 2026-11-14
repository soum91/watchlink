import XCTest

final class ReportActionsTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let scan = app.buttons["scan.run"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15))
        scan.tap()
        let saved = app.staticTexts["Report saved. No pairing changes made."].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        reveal("report.copy")
    }
    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0, let app {
            print("WATCHLINK_UI_FAILURE_HIERARCHY\n" + app.debugDescription)
        }
        app?.terminate(); app = nil
    }
    private func reveal(_ identifier: String) {
        let control = app.buttons[identifier]
        for _ in 0..<12 {
            if control.exists && control.isHittable { return }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.59))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(control.isHittable, "Report action must be reachable")
    }
    private func sheet(_ identifier: String) -> XCUIElement {
        // UIActivityViewController replaces its root view when the remote sheet loads.
        let identifiers = identifier == "report.shareSheet"
            ? [identifier, "ActivityListView", "ShareSheet.RemoteContainerView", "UIActivityContentView"]
            : [identifier]
        return app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN %@", identifiers)).firstMatch
    }
    func testCopyDoesNotOpenShareOrSave() {
        app.buttons["report.copy"].tap()
        let status = app.staticTexts["report.status"]
        expectation(for: NSPredicate(format: "label == %@", "Report copied."), evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(sheet("report.shareSheet").exists)
        XCTAssertFalse(sheet("report.exportSheet").exists)
        XCTAssertEqual(app.state, .runningForeground)
    }
    func testSaveOpensOnlyDocumentPickerAndCanRepeatAfterCancel() {
        for _ in 0..<2 {
            reveal("report.save")
            app.buttons["report.save"].tap()
            XCTAssertTrue(sheet("report.exportSheet").waitForExistence(timeout: 15))
            XCTAssertFalse(sheet("report.shareSheet").exists)
            XCTAssertEqual(app.state, .runningForeground)
            let cancel = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 10))
            // A freshly provisioned simulator may put the keyboard's first-use
            // tutorial above Files. Dismiss only that identified system tutorial.
            for _ in 0..<3 {
                let tutorial = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
                if tutorial.waitForExistence(timeout: 2) {
                    let proceed = app.buttons["Continue"].firstMatch
                    XCTAssertTrue(proceed.waitForExistence(timeout: 5))
                    proceed.tap()
                }
                if !sheet("report.exportSheet").exists { break }
                cancel.tap()
                let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                         object: sheet("report.exportSheet"))
                if XCTWaiter.wait(for: [dismissed], timeout: 3) == .completed { break }
            }
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheet("report.exportSheet"))
            waitForExpectations(timeout: 10)
        }
        reveal("report.copy")
        app.buttons["report.copy"].tap()
        XCTAssertEqual(app.state, .runningForeground)
    }
    func testShareOpensOnlyShareController() {
        app.buttons["report.share"].tap()
        XCTAssertTrue(sheet("report.shareSheet").waitForExistence(timeout: 15))
        XCTAssertFalse(sheet("report.exportSheet").exists)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
