import Foundation
@testable import UltraKiosk

// MARK: - MockBrightnessManager

/// Test double for BrightnessControlling.
/// Records every call so tests can assert which brightness operations were triggered.
/// Does not touch UIScreen, making it safe for host-app-free unit test targets.
final class MockBrightnessManager: BrightnessControlling {
    private(set) var saveAndSetCallCount = 0
    private(set) var restoreCallCount = 0
    private(set) var dimCallCount = 0
    private(set) var setNormalCallCount = 0

    func saveAndSetBrightness() { saveAndSetCallCount += 1 }
    func restoreOriginalBrightness() { restoreCallCount += 1 }
    func dimScreen() { dimCallCount += 1 }
    func setNormalBrightness() { setNormalCallCount += 1 }

    func reset() {
        saveAndSetCallCount = 0
        restoreCallCount = 0
        dimCallCount = 0
        setNormalCallCount = 0
    }
}

// MARK: - UserDefaults test suite helpers

extension UserDefaults {
    /// Returns a fresh, isolated UserDefaults suite for use in a single test.
    /// Call removeSuite() in tearDown to clean up.
    static func testSuite(name: String = "test.ultrakiosk") -> UserDefaults {
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    func removeSuite(name: String = "test.ultrakiosk") {
        removePersistentDomain(forName: name)
    }
}
