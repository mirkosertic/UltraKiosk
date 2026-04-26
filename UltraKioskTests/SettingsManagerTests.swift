import XCTest
import Combine
@testable import UltraKiosk

final class SettingsManagerTests: XCTestCase {

    private var sut: SettingsManager!
    private var testDefaults: UserDefaults!
    private var cancellables: Set<AnyCancellable>!

    private static let suiteName = "test.ultrakiosk.settings"

    override func setUp() {
        super.setUp()
        testDefaults = .testSuite(name: Self.suiteName)
        sut = SettingsManager(userDefaults: testDefaults)
        cancellables = []
    }

    override func tearDown() {
        testDefaults.removeSuite(name: Self.suiteName)
        sut = nil
        testDefaults = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Default Values

    func testDefaultValues_slideshowURLs_isEmpty() {
        XCTAssertEqual(sut.slideshowURLs, [])
    }

    func testDefaultValues_slideshowInterval_is30() {
        XCTAssertEqual(sut.slideshowInterval, 30.0, accuracy: 0.001)
    }

    func testDefaultValues_screensaverTimeout_is60() {
        XCTAssertEqual(sut.screensaverTimeout, 60.0, accuracy: 0.001)
    }

    func testDefaultValues_screenBrightnessDimmed_is02() {
        XCTAssertEqual(sut.screenBrightnessDimmed, 0.2, accuracy: 0.001)
    }

    func testDefaultValues_screenBrightnessNormal_is07() {
        XCTAssertEqual(sut.screenBrightnessNormal, 0.7, accuracy: 0.001)
    }

    func testDefaultValues_enableMQTT_isTrue() {
        XCTAssertTrue(sut.enableMQTT)
    }

    func testDefaultValues_faceDetectionInterval_is1() {
        XCTAssertEqual(sut.faceDetectionInterval, 1.0, accuracy: 0.001)
    }

    func testDefaultValues_voiceSampleRate_is16000() {
        XCTAssertEqual(sut.voiceSampleRate, 16000)
    }

    func testDefaultValues_voiceTimeout_is2() {
        XCTAssertEqual(sut.voiceTimeout, 2)
    }

    // MARK: - effectiveURLs

    func testEffectiveURLs_emptyList_returnsEmpty() {
        sut.slideshowURLs = []
        XCTAssertEqual(sut.effectiveURLs, [])
    }

    func testEffectiveURLs_filtersEmptyStrings() {
        sut.slideshowURLs = ["https://a.com", "", "https://b.com", ""]
        XCTAssertEqual(sut.effectiveURLs, ["https://a.com", "https://b.com"])
    }

    func testEffectiveURLs_allEmpty_returnsEmpty() {
        sut.slideshowURLs = ["", "", ""]
        XCTAssertEqual(sut.effectiveURLs, [])
    }

    func testEffectiveURLs_noEmptyStrings_returnsAll() {
        sut.slideshowURLs = ["https://a.com", "https://b.com"]
        XCTAssertEqual(sut.effectiveURLs, ["https://a.com", "https://b.com"])
    }

    // MARK: - Save & Load Round-Trip

    func testSaveAndLoad_slideshowURLs_roundtrip() {
        let urls = ["https://dashboard1.local", "https://dashboard2.local"]
        sut.slideshowURLs = urls
        sut.saveSettings()

        let reloaded = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(reloaded.slideshowURLs, urls)
    }

    func testSaveAndLoad_slideshowURLs_emptyList_roundtrip() {
        sut.slideshowURLs = []
        sut.saveSettings()

        let reloaded = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(reloaded.slideshowURLs, [])
    }

    func testSaveAndLoad_slideshowInterval_roundtrip() {
        sut.slideshowInterval = 45.0
        sut.saveSettings()

        let reloaded = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(reloaded.slideshowInterval, 45.0, accuracy: 0.001)
    }

    func testSaveAndLoad_screensaverTimeout_roundtrip() {
        sut.screensaverTimeout = 120.0
        sut.saveSettings()

        let reloaded = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(reloaded.screensaverTimeout, 120.0, accuracy: 0.001)
    }

    func testSaveAndLoad_homeAssistantSettings_roundtrip() {
        sut.homeAssistantIP = "192.168.1.42"
        sut.homeAssistantPort = "8123"
        sut.useHTTPS = true
        sut.saveSettings()

        let reloaded = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(reloaded.homeAssistantIP, "192.168.1.42")
        XCTAssertEqual(reloaded.homeAssistantPort, "8123")
        XCTAssertTrue(reloaded.useHTTPS)
    }

    func testSaveAndLoad_mqttSettings_roundtrip() {
        sut.enableMQTT = false
        sut.mqttBrokerIP = "mqtt.local"
        sut.mqttPort = "8883"
        sut.mqttUseTLS = true
        sut.saveSettings()

        let reloaded = SettingsManager(userDefaults: testDefaults)
        XCTAssertFalse(reloaded.enableMQTT)
        XCTAssertEqual(reloaded.mqttBrokerIP, "mqtt.local")
        XCTAssertEqual(reloaded.mqttPort, "8883")
        XCTAssertTrue(reloaded.mqttUseTLS)
    }

    func testSaveAndLoad_booleanFalse_notLostToMissingKeyDefault() {
        // Verify that an explicitly saved `false` survives a reload
        // (guard against the nil-check pattern for booleans misreading stored false as absent)
        sut.enableMQTT = false
        sut.saveSettings()

        let reloaded = SettingsManager(userDefaults: testDefaults)
        XCTAssertFalse(reloaded.enableMQTT)
    }

    // MARK: - Migration from Legacy kioskURL

    func testMigration_explicitKioskURL_migratesIntoList() {
        testDefaults.set("http://ha.local:8123/dashboard", forKey: "kioskURL")

        let migrated = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(migrated.slideshowURLs, ["http://ha.local:8123/dashboard"])
    }

    func testMigration_emptyKioskURL_resultsInEmptyList() {
        testDefaults.set("", forKey: "kioskURL")

        let migrated = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(migrated.slideshowURLs, [])
    }

    func testMigration_noKioskURL_freshInstall_resultsInEmptyList() {
        // No kioskURL key at all → demo mode, not the hardcoded fallback URL
        let fresh = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(fresh.slideshowURLs, [])
    }

    func testMigration_existingSlideshowURLs_notOverwrittenByKioskURL() {
        // If slideshowURLs already stored, legacy kioskURL must not overwrite it
        let existingURLs = ["https://slide1.com", "https://slide2.com"]
        let encoded = try! JSONEncoder().encode(existingURLs)
        testDefaults.set(encoded, forKey: "slideshowURLs")
        testDefaults.set("http://legacy.local", forKey: "kioskURL")

        let loaded = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(loaded.slideshowURLs, existingURLs)
    }

    // MARK: - Reset To Defaults

    func testResetToDefaults_clearsSlideshowURLs() {
        sut.slideshowURLs = ["https://a.com", "https://b.com"]
        sut.resetToDefaults()
        XCTAssertEqual(sut.slideshowURLs, [])
    }

    func testResetToDefaults_resetsSlideshowInterval() {
        sut.slideshowInterval = 99.0
        sut.resetToDefaults()
        XCTAssertEqual(sut.slideshowInterval, 30.0, accuracy: 0.001)
    }

    func testResetToDefaults_resetsScreensaverTimeout() {
        sut.screensaverTimeout = 300.0
        sut.resetToDefaults()
        XCTAssertEqual(sut.screensaverTimeout, 60.0, accuracy: 0.001)
    }

    func testResetToDefaults_setsVoiceActivationFalse() {
        sut.enableVoiceActivation = true
        sut.resetToDefaults()
        XCTAssertFalse(sut.enableVoiceActivation)
    }

    func testResetToDefaults_clearsKioskURL() {
        sut.kioskURL = "https://something.local"
        sut.resetToDefaults()
        XCTAssertEqual(sut.kioskURL, "")
    }

    // MARK: - Validation

    func testValidateSettings_validConfig_returnsNoIssues() {
        sut.homeAssistantPort = "8123"
        sut.accessToken = "valid_token"
        sut.enableMQTT = false
        sut.screensaverTimeout = 60.0
        sut.faceDetectionInterval = 1.0
        XCTAssertTrue(sut.validateSettings().isEmpty)
    }

    func testValidateSettings_invalidHAPort_returnsIssue() {
        sut.homeAssistantPort = "99999"
        sut.accessToken = "valid_token"
        sut.enableMQTT = false
        XCTAssertFalse(sut.validateSettings().isEmpty)
    }

    func testValidateSettings_nonNumericHAPort_returnsIssue() {
        sut.homeAssistantPort = "abc"
        sut.accessToken = "valid_token"
        sut.enableMQTT = false
        XCTAssertFalse(sut.validateSettings().isEmpty)
    }

    func testValidateSettings_emptyAccessToken_returnsIssue() {
        sut.homeAssistantPort = "8123"
        sut.accessToken = ""
        sut.enableMQTT = false
        let issues = sut.validateSettings()
        XCTAssertTrue(issues.contains { $0.localizedCaseInsensitiveContains("token") })
    }

    func testValidateSettings_mqttEnabled_invalidMQTTPort_returnsIssue() {
        sut.homeAssistantPort = "8123"
        sut.accessToken = "valid_token"
        sut.enableMQTT = true
        sut.mqttPort = "0"
        let issues = sut.validateSettings()
        XCTAssertTrue(issues.contains { $0.localizedCaseInsensitiveContains("mqtt") })
    }

    func testValidateSettings_mqttDisabled_invalidMQTTPort_isIgnored() {
        sut.homeAssistantPort = "8123"
        sut.accessToken = "valid_token"
        sut.enableMQTT = false
        sut.mqttPort = "0"
        sut.screensaverTimeout = 60.0
        sut.faceDetectionInterval = 1.0
        XCTAssertTrue(sut.validateSettings().isEmpty)
    }

    func testValidateSettings_screensaverTimeoutTooShort_returnsIssue() {
        sut.homeAssistantPort = "8123"
        sut.accessToken = "valid_token"
        sut.enableMQTT = false
        sut.screensaverTimeout = 5.0
        XCTAssertFalse(sut.validateSettings().isEmpty)
    }

    func testValidateSettings_faceDetectionIntervalTooShort_returnsIssue() {
        sut.homeAssistantPort = "8123"
        sut.accessToken = "valid_token"
        sut.enableMQTT = false
        sut.screensaverTimeout = 60.0
        sut.faceDetectionInterval = 0.05
        XCTAssertFalse(sut.validateSettings().isEmpty)
    }

    // MARK: - Computed URLs

    func testHomeAssistantBaseURL_http() {
        sut.homeAssistantIP = "192.168.1.100"
        sut.homeAssistantPort = "8123"
        sut.useHTTPS = false
        XCTAssertEqual(sut.homeAssistantBaseURL, "http://192.168.1.100:8123")
    }

    func testHomeAssistantBaseURL_https() {
        sut.homeAssistantIP = "ha.example.com"
        sut.homeAssistantPort = "443"
        sut.useHTTPS = true
        XCTAssertEqual(sut.homeAssistantBaseURL, "https://ha.example.com:443")
    }

    func testHomeAssistantWebSocketURL_ws() {
        sut.homeAssistantIP = "192.168.1.100"
        sut.homeAssistantPort = "8123"
        sut.useHTTPS = false
        XCTAssertEqual(sut.homeAssistantWebSocketURL, "ws://192.168.1.100:8123")
    }

    func testHomeAssistantWebSocketURL_wss() {
        sut.homeAssistantIP = "ha.example.com"
        sut.homeAssistantPort = "443"
        sut.useHTTPS = true
        XCTAssertEqual(sut.homeAssistantWebSocketURL, "wss://ha.example.com:443")
    }

    func testMQTTBrokerURL_plain() {
        sut.mqttBrokerIP = "192.168.1.100"
        sut.mqttPort = "1883"
        sut.mqttUseTLS = false
        XCTAssertEqual(sut.mqttBrokerURL, "mqtt://192.168.1.100:1883")
    }

    func testMQTTBrokerURL_tls() {
        sut.mqttBrokerIP = "mqtt.example.com"
        sut.mqttPort = "8883"
        sut.mqttUseTLS = true
        XCTAssertEqual(sut.mqttBrokerURL, "mqtts://mqtt.example.com:8883")
    }

    // MARK: - Formatted Values

    func testScreensaverTimeoutFormatted_underOneMinute() {
        sut.screensaverTimeout = 45.0
        XCTAssertEqual(sut.screensaverTimeoutFormatted, "0:45")
    }

    func testScreensaverTimeoutFormatted_exactlyOneMinute() {
        sut.screensaverTimeout = 60.0
        XCTAssertEqual(sut.screensaverTimeoutFormatted, "1:00")
    }

    func testScreensaverTimeoutFormatted_ninetySeconds() {
        sut.screensaverTimeout = 90.0
        XCTAssertEqual(sut.screensaverTimeoutFormatted, "1:30")
    }

    func testBatteryUpdateIntervalFormatted_seconds() {
        sut.mqttBatteryUpdateInterval = 30.0
        XCTAssertEqual(sut.batteryUpdateIntervalFormatted, "30s")
    }

    func testBatteryUpdateIntervalFormatted_minutes() {
        sut.mqttBatteryUpdateInterval = 120.0
        XCTAssertEqual(sut.batteryUpdateIntervalFormatted, "2m")
    }

    // MARK: - Export / Import

    func testExportImport_slideshowURLs_roundtrip() {
        sut.slideshowURLs = ["https://dash1.local", "https://dash2.local"]
        sut.slideshowInterval = 45.0
        let exported = sut.exportSettings()

        let importSuite = UserDefaults.testSuite(name: "test.ultrakiosk.import")
        let fresh = SettingsManager(userDefaults: importSuite)
        fresh.importSettings(exported)

        XCTAssertEqual(fresh.slideshowURLs, ["https://dash1.local", "https://dash2.local"])
        XCTAssertEqual(fresh.slideshowInterval, 45.0, accuracy: 0.001)

        importSuite.removeSuite(name: "test.ultrakiosk.import")
    }

    func testExportImport_homeAssistantSettings_roundtrip() {
        sut.homeAssistantIP = "192.168.1.50"
        sut.homeAssistantPort = "8123"
        sut.useHTTPS = true
        let exported = sut.exportSettings()

        let importSuite = UserDefaults.testSuite(name: "test.ultrakiosk.import2")
        let fresh = SettingsManager(userDefaults: importSuite)
        fresh.importSettings(exported)

        XCTAssertEqual(fresh.homeAssistantIP, "192.168.1.50")
        XCTAssertEqual(fresh.homeAssistantPort, "8123")
        XCTAssertTrue(fresh.useHTTPS)

        importSuite.removeSuite(name: "test.ultrakiosk.import2")
    }

    func testExportSettings_containsExpectedKeys() {
        let exported = sut.exportSettings()
        XCTAssertNotNil(exported["homeAssistantIP"])
        XCTAssertNotNil(exported["screensaverTimeout"])
        XCTAssertNotNil(exported["slideshowURLs"])
        XCTAssertNotNil(exported["slideshowInterval"])
    }

    // MARK: - settingsChanged Notification

    func testSaveSettings_postsSettingsChangedNotification() {
        let expectation = expectation(description: "settingsChanged posted")
        let token = NotificationCenter.default.addObserver(
            forName: .settingsChanged,
            object: nil,
            queue: .main
        ) { _ in expectation.fulfill() }

        sut.saveSettings()

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(token)
    }

    // MARK: - Reactive Publishing

    func testSlideshowURLs_publishesOnChange() {
        let expectation = expectation(description: "slideshowURLs change published")
        sut.$slideshowURLs
            .dropFirst()
            .sink { urls in
                XCTAssertEqual(urls, ["https://new.local"])
                expectation.fulfill()
            }
            .store(in: &cancellables)

        sut.slideshowURLs = ["https://new.local"]
        wait(for: [expectation], timeout: 1.0)
    }
}
