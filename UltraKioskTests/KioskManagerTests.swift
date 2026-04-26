import XCTest
import Combine
@testable import UltraKiosk

final class KioskManagerTests: XCTestCase {

    private var sut: KioskManager!
    private var mockBrightness: MockBrightnessManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockBrightness = MockBrightnessManager()
        sut = KioskManager(brightnessManager: mockBrightness)
        cancellables = []
    }

    override func tearDown() {
        sut.inactivityTimer?.invalidate()
        sut = nil
        mockBrightness = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_screensaverIsInactive() {
        XCTAssertFalse(sut.isScreensaverActive)
    }

    func testInitialState_noActiveTimer() {
        XCTAssertNil(sut.inactivityTimer)
    }

    // MARK: - activateScreensaver

    func testActivateScreensaver_setsScreensaverActiveTrue() {
        sut.activateScreensaver()
        XCTAssertTrue(sut.isScreensaverActive)
    }

    func testActivateScreensaver_callsDimScreenOnce() {
        sut.activateScreensaver()
        XCTAssertEqual(mockBrightness.dimCallCount, 1)
    }

    func testActivateScreensaver_doesNotCallSetNormal() {
        sut.activateScreensaver()
        XCTAssertEqual(mockBrightness.setNormalCallCount, 0)
    }

    func testActivateScreensaver_calledTwice_dimCalledTwice() {
        sut.activateScreensaver()
        sut.activateScreensaver()
        XCTAssertEqual(mockBrightness.dimCallCount, 2)
    }

    // MARK: - exitScreensaver

    func testExitScreensaver_clearsScreensaverFlag() {
        sut.activateScreensaver()
        sut.exitScreensaver()
        XCTAssertFalse(sut.isScreensaverActive)
    }

    func testExitScreensaver_callsSetNormalBrightness() {
        sut.activateScreensaver()
        sut.exitScreensaver()
        XCTAssertEqual(mockBrightness.setNormalCallCount, 1)
    }

    func testExitScreensaver_doesNotCallDim() {
        sut.activateScreensaver()
        mockBrightness.reset()
        sut.exitScreensaver()
        XCTAssertEqual(mockBrightness.dimCallCount, 0)
    }

    func testExitScreensaver_startsInactivityTimer() {
        sut.activateScreensaver()
        sut.exitScreensaver()
        XCTAssertNotNil(sut.inactivityTimer)
        XCTAssertTrue(sut.inactivityTimer?.isValid ?? false)
    }

    // MARK: - handleUserActivity

    func testHandleUserActivity_whenScreensaverActive_exitsScreensaver() {
        sut.activateScreensaver()
        sut.handleUserActivity()
        XCTAssertFalse(sut.isScreensaverActive)
    }

    func testHandleUserActivity_whenScreensaverActive_callsSetNormal() {
        sut.activateScreensaver()
        mockBrightness.reset()
        sut.handleUserActivity()
        XCTAssertEqual(mockBrightness.setNormalCallCount, 1)
    }

    func testHandleUserActivity_whenScreensaverInactive_doesNotActivateScreensaver() {
        sut.startInactivityMonitoring()
        sut.handleUserActivity()
        XCTAssertFalse(sut.isScreensaverActive)
    }

    func testHandleUserActivity_whenScreensaverInactive_invalidatesOldTimer() {
        sut.startInactivityMonitoring()
        let oldTimer = sut.inactivityTimer

        sut.handleUserActivity()

        XCTAssertFalse(oldTimer?.isValid ?? true)
    }

    func testHandleUserActivity_whenScreensaverInactive_createsNewTimer() {
        sut.startInactivityMonitoring()
        sut.handleUserActivity()
        XCTAssertNotNil(sut.inactivityTimer)
        XCTAssertTrue(sut.inactivityTimer?.isValid ?? false)
    }

    // MARK: - startInactivityMonitoring

    func testStartInactivityMonitoring_createsValidTimer() {
        sut.startInactivityMonitoring()
        XCTAssertNotNil(sut.inactivityTimer)
        XCTAssertTrue(sut.inactivityTimer?.isValid ?? false)
    }

    func testStartInactivityMonitoring_calledTwice_doesNotLeakTimer() {
        sut.startInactivityMonitoring()
        let firstTimer = sut.inactivityTimer
        sut.startInactivityMonitoring()

        XCTAssertFalse(firstTimer?.isValid ?? true)
        XCTAssertNotNil(sut.inactivityTimer)
    }

    // MARK: - updateTimeout

    func testUpdateTimeout_whenScreensaverInactive_recreatesTimer() {
        sut.startInactivityMonitoring()
        let oldTimer = sut.inactivityTimer

        sut.updateTimeout(200.0)

        XCTAssertFalse(oldTimer?.isValid ?? true)
        XCTAssertNotNil(sut.inactivityTimer)
    }

    func testUpdateTimeout_whenScreensaverActive_doesNotStartTimer() {
        sut.activateScreensaver()
        sut.updateTimeout(200.0)
        // Timer must not start while screensaver is showing
        XCTAssertNil(sut.inactivityTimer)
    }

    // MARK: - Timer fires (integration)

    func testInactivityTimer_firesAndActivatesScreensaver() {
        sut.updateTimeout(0.1)  // 100 ms
        sut.startInactivityMonitoring()

        let expectation = expectation(description: "Screensaver activates after timeout")
        sut.$isScreensaverActive
            .dropFirst()
            .filter { $0 }
            .first()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(sut.isScreensaverActive)
        XCTAssertEqual(mockBrightness.dimCallCount, 1)
    }

    func testInactivityTimer_doesNotFireAfterScreensaverExited() {
        sut.updateTimeout(0.1)
        sut.startInactivityMonitoring()

        // Wait for screensaver to activate
        let activated = expectation(description: "Screensaver activates")
        sut.$isScreensaverActive.dropFirst().filter { $0 }.first()
            .sink { _ in activated.fulfill() }
            .store(in: &cancellables)
        wait(for: [activated], timeout: 2.0)

        // Exit screensaver — this resets the timer with the same 0.1 s timeout
        sut.exitScreensaver()
        XCTAssertFalse(sut.isScreensaverActive)

        // Wait again for second activation
        let reactivated = expectation(description: "Screensaver reactivates")
        sut.$isScreensaverActive.dropFirst().filter { $0 }.first()
            .sink { _ in reactivated.fulfill() }
            .store(in: &cancellables)
        wait(for: [reactivated], timeout: 2.0)

        XCTAssertTrue(sut.isScreensaverActive)
        XCTAssertEqual(mockBrightness.dimCallCount, 2)
    }

    // MARK: - Publisher behaviour

    func testIsScreensaverActive_publishesActivateAndDeactivate() {
        let expectation = expectation(description: "Two state changes published")
        var received: [Bool] = []

        sut.$isScreensaverActive
            .dropFirst()
            .sink { value in
                received.append(value)
                if received.count == 2 { expectation.fulfill() }
            }
            .store(in: &cancellables)

        sut.activateScreensaver()
        sut.exitScreensaver()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received, [true, false])
    }
}
