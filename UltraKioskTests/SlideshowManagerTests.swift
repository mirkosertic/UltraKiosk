import XCTest
import Combine
@testable import UltraKiosk

final class SlideshowManagerTests: XCTestCase {

    private var sut: SlideshowManager!
    private var settings: SettingsManager!
    private var kioskManager: KioskManager!
    private var mockBrightness: MockBrightnessManager!
    private var cancellables: Set<AnyCancellable>!

    private static let suiteName = "test.ultrakiosk.slideshow"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.testSuite(name: Self.suiteName)
        settings = SettingsManager(userDefaults: defaults)
        mockBrightness = MockBrightnessManager()
        kioskManager = KioskManager(brightnessManager: mockBrightness)
        sut = SlideshowManager()
        cancellables = []
    }

    override func tearDown() {
        sut = nil
        kioskManager.inactivityTimer?.invalidate()
        kioskManager = nil
        settings = nil
        UserDefaults.testSuite(name: Self.suiteName).removeSuite(name: Self.suiteName)
        cancellables = nil
        super.tearDown()
    }

    /// Convenience: configure the SlideshowManager with the given URLs and interval,
    /// then let the RunLoop process the initial Combine emissions.
    private func configure(urls: [String], interval: Double = 30.0) {
        settings.slideshowURLs = urls
        settings.slideshowInterval = interval
        sut.configure(settings: settings, kioskManager: kioskManager)
        // Let the @Published initial-value emissions reach the Combine subscribers
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    }

    // MARK: - Initial State

    func testInitialIndex_isZero() {
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: - No-op with 0 or 1 URL

    func testStart_withZeroURLs_indexRemainsZero() {
        configure(urls: [])
        sut.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testStart_withOneURL_indexRemainsZero() {
        configure(urls: ["https://a.com"])
        sut.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testStart_withEmptyStringURL_treatedAsSingleInvalidEntry_indexRemainsZero() {
        configure(urls: [""])  // effectiveURLs is empty
        sut.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: - Timer & Index Advance

    func testAdvance_withTwoURLs_indexAdvancesToOne() {
        configure(urls: ["https://a.com", "https://b.com"], interval: 0.1)

        let expectation = expectation(description: "Index advances to 1")
        sut.$currentIndex
            .dropFirst()
            .first { $0 == 1 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        sut.start()
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(sut.currentIndex, 1)
    }

    func testAdvance_wrapsAroundToZero_afterLastSlide() {
        configure(urls: ["https://a.com", "https://b.com"], interval: 0.1)

        let expectation = expectation(description: "Index wraps to 0")
        var received: [Int] = []

        sut.$currentIndex
            .dropFirst()
            .sink { index in
                received.append(index)
                if received == [1, 0] { expectation.fulfill() }
            }
            .store(in: &cancellables)

        sut.start()
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testAdvance_withThreeURLs_cyclesThroughAll() {
        configure(urls: ["https://a.com", "https://b.com", "https://c.com"], interval: 0.1)

        let expectation = expectation(description: "Cycles through three slides")
        var received: [Int] = []

        sut.$currentIndex
            .dropFirst()
            .sink { index in
                received.append(index)
                if received.count >= 3 { expectation.fulfill() }
            }
            .store(in: &cancellables)

        sut.start()
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(Array(received.prefix(3)), [1, 2, 0])
    }

    // MARK: - Index Clamping

    func testRestart_clampsIndex_whenURLListShrinks() {
        configure(urls: ["https://a.com", "https://b.com", "https://c.com"], interval: 30.0)
        sut.start()
        sut.currentIndex = 2

        // Shrink list to 1 URL — restart must clamp index to 0
        settings.slideshowURLs = ["https://a.com"]
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testRestart_keepsIndex_whenURLListGrows() {
        configure(urls: ["https://a.com", "https://b.com"], interval: 30.0)
        sut.start()
        sut.currentIndex = 1

        // Grow list — existing index 1 is still valid, must not be reset
        settings.slideshowURLs = ["https://a.com", "https://b.com", "https://c.com"]
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(sut.currentIndex, 1)
    }

    // MARK: - Screensaver Interaction

    func testScreensaverActivation_pausesSlideshow() {
        // Use a 30 s interval so the timer never fires during this test.
        configure(urls: ["https://a.com", "https://b.com"], interval: 30.0)
        sut.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        kioskManager.activateScreensaver()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        // Switch to a short interval — the timer must NOT restart while paused.
        settings.slideshowInterval = 0.1
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        // Index stays at 0; the timer was suppressed by the screensaver guard.
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testScreensaverActivation_preservesCurrentIndex() {
        configure(urls: ["https://a.com", "https://b.com"], interval: 0.1)
        sut.start()

        // Wait for the first advance
        let advanced = expectation(description: "First advance")
        sut.$currentIndex.dropFirst().first().sink { _ in advanced.fulfill() }
            .store(in: &cancellables)
        wait(for: [advanced], timeout: 1.0)

        let indexBeforePause = sut.currentIndex
        XCTAssertEqual(indexBeforePause, 1)

        kioskManager.activateScreensaver()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        // Index must be unchanged after pause
        XCTAssertEqual(sut.currentIndex, indexBeforePause)
    }

    func testScreensaverDeactivation_resumesTimer() {
        configure(urls: ["https://a.com", "https://b.com"], interval: 0.1)
        sut.start()

        // Wait for first advance
        let firstAdvance = expectation(description: "First advance")
        sut.$currentIndex.dropFirst().first().sink { _ in firstAdvance.fulfill() }
            .store(in: &cancellables)
        wait(for: [firstAdvance], timeout: 1.0)

        // Pause
        kioskManager.activateScreensaver()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let indexAfterPause = sut.currentIndex

        // Subscribe before resuming to avoid missing the transition
        let resumed = expectation(description: "Index advances after resume")
        sut.$currentIndex
            .dropFirst()
            .first { $0 != indexAfterPause }
            .sink { _ in resumed.fulfill() }
            .store(in: &cancellables)

        kioskManager.exitScreensaver()
        wait(for: [resumed], timeout: 2.0)

        XCTAssertNotEqual(sut.currentIndex, indexAfterPause)
    }

    // MARK: - Settings Changes at Runtime

    func testURLListChange_triggersRestart_clampsIndex() {
        configure(urls: ["https://a.com", "https://b.com"], interval: 30.0)
        sut.start()
        sut.currentIndex = 1

        // Shrink to one URL — restart must clamp
        settings.slideshowURLs = ["https://only.com"]
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testIntervalChange_restartsTimerWithNewInterval() {
        configure(urls: ["https://a.com", "https://b.com"], interval: 30.0)
        sut.start()

        // Switch to short interval → timer should now fire quickly
        let advanced = expectation(description: "Index advances after interval change")
        sut.$currentIndex.dropFirst().first()
            .sink { _ in advanced.fulfill() }
            .store(in: &cancellables)

        settings.slideshowInterval = 0.1
        wait(for: [advanced], timeout: 2.0)

        XCTAssertGreaterThan(sut.currentIndex, 0)
    }

    func testAddingSecondURL_startsTimer() {
        // Start with single URL (no timer)
        configure(urls: ["https://a.com"], interval: 0.1)
        sut.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        XCTAssertEqual(sut.currentIndex, 0)  // No advance with 1 URL

        // Add second URL → timer must kick in
        let advanced = expectation(description: "Timer starts after second URL added")
        sut.$currentIndex.dropFirst().first()
            .sink { _ in advanced.fulfill() }
            .store(in: &cancellables)

        settings.slideshowURLs = ["https://a.com", "https://b.com"]
        wait(for: [advanced], timeout: 2.0)

        XCTAssertEqual(sut.currentIndex, 1)
    }
}
