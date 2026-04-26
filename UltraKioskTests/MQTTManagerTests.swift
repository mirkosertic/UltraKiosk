import XCTest
import UIKit
@testable import UltraKiosk

/// Tests for the pure-logic static helpers on MQTTManager.
/// All tested functions are static, so no MQTTManager instance (and therefore no
/// SettingsManager.shared access or CocoaMQTT network setup) is required.
final class MQTTManagerTests: XCTestCase {

    // MARK: - batteryStateToString

    func testBatteryStateToString_unknown_returnsUnknown() {
        XCTAssertEqual(MQTTManager.batteryStateToString(.unknown), "unknown")
    }

    func testBatteryStateToString_unplugged_returnsUnplugged() {
        XCTAssertEqual(MQTTManager.batteryStateToString(.unplugged), "unplugged")
    }

    func testBatteryStateToString_charging_returnsCharging() {
        XCTAssertEqual(MQTTManager.batteryStateToString(.charging), "charging")
    }

    func testBatteryStateToString_full_returnsFull() {
        XCTAssertEqual(MQTTManager.batteryStateToString(.full), "full")
    }

    func testBatteryStateToString_allCases_returnNonEmptyStrings() {
        let cases: [UIDevice.BatteryState] = [.unknown, .unplugged, .charging, .full]
        for state in cases {
            XCTAssertFalse(MQTTManager.batteryStateToString(state).isEmpty,
                           "batteryStateToString returned empty for state \(state.rawValue)")
        }
    }

    // MARK: - formatNumberPayload — integers (no decimal point)

    func testFormatNumberPayload_zero_returnsZeroString() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(0.0), "0")
    }

    func testFormatNumberPayload_positiveInteger_noDecimalPoint() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(42.0), "42")
    }

    func testFormatNumberPayload_negativeInteger_noDecimalPoint() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(-5.0), "-5")
    }

    func testFormatNumberPayload_largeInteger_noDecimalPoint() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(1800.0), "1800")
    }

    func testFormatNumberPayload_one_noDecimalPoint() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(1.0), "1")
    }

    func testFormatNumberPayload_integerValue_doesNotContainDecimalPoint() {
        let result = MQTTManager.formatNumberPayload(60.0)
        XCTAssertFalse(result.contains("."), "Integer payload must not contain a decimal point")
    }

    // MARK: - formatNumberPayload — decimals (three decimal places)

    func testFormatNumberPayload_halfValue_threeDecimalPlaces() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(42.5), "42.500")
    }

    func testFormatNumberPayload_smallDecimal_threeDecimalPlaces() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(0.05), "0.050")
    }

    func testFormatNumberPayload_decimalWithTrailingZero_threeDecimalPlaces() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(0.1), "0.100")
    }

    func testFormatNumberPayload_threeSignificantDecimals_exact() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(0.123), "0.123")
    }

    func testFormatNumberPayload_negativeDecimal_threeDecimalPlaces() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(-0.5), "-0.500")
    }

    func testFormatNumberPayload_decimalValue_containsDecimalPoint() {
        let result = MQTTManager.formatNumberPayload(1.5)
        XCTAssertTrue(result.contains("."), "Decimal payload must contain a decimal point")
    }

    func testFormatNumberPayload_irrationalFraction_threeDecimalPlaces() {
        // 1.0/3.0 cannot be integer — must use the three-decimal-place format
        let result = MQTTManager.formatNumberPayload(1.0 / 3.0)
        XCTAssertTrue(result.contains("."),
                      "Expected decimal format for 1/3, got: \(result)")
        // Must have exactly 3 digits after the decimal point
        if let dotIndex = result.firstIndex(of: ".") {
            let fractionalPart = result[result.index(after: dotIndex)...]
            XCTAssertEqual(fractionalPart.count, 3,
                           "Expected 3 decimal places, got: \(fractionalPart)")
        }
    }

    // MARK: - formatNumberPayload — known HA-relevant values

    func testFormatNumberPayload_screensaverTimeout60_integerFormat() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(60.0), "60")
    }

    func testFormatNumberPayload_brightnessPoint7_decimalFormat() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(0.7), "0.700")
    }

    func testFormatNumberPayload_brightnessPoint05_decimalFormat() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(0.05), "0.050")
    }

    func testFormatNumberPayload_batteryInterval120_integerFormat() {
        XCTAssertEqual(MQTTManager.formatNumberPayload(120.0), "120")
    }

    // MARK: - computeDeviceSerializedId — format invariants

    func testComputeDeviceSerializedId_startsWithIpad() {
        XCTAssertTrue(MQTTManager.computeDeviceSerializedId().hasPrefix("ipad_"))
    }

    func testComputeDeviceSerializedId_has17Characters() {
        // "ipad_" (5 chars) + 12 hex chars = 17 total
        XCTAssertEqual(MQTTManager.computeDeviceSerializedId().count, 17)
    }

    func testComputeDeviceSerializedId_isEntirelyLowercase() {
        let id = MQTTManager.computeDeviceSerializedId()
        XCTAssertEqual(id, id.lowercased(), "Device ID must be lowercase")
    }

    func testComputeDeviceSerializedId_containsNoHyphens() {
        XCTAssertFalse(MQTTManager.computeDeviceSerializedId().contains("-"),
                       "Device ID must not contain hyphens")
    }

    func testComputeDeviceSerializedId_isStableAcrossCalls() {
        let first  = MQTTManager.computeDeviceSerializedId()
        let second = MQTTManager.computeDeviceSerializedId()
        XCTAssertEqual(first, second, "Device ID must be deterministic")
    }

    func testComputeDeviceSerializedId_suffixIsAlphanumeric() {
        let id = MQTTManager.computeDeviceSerializedId()
        let suffix = String(id.dropFirst(5))  // remove "ipad_"
        let alphanumeric = CharacterSet.alphanumerics
        for scalar in suffix.unicodeScalars {
            XCTAssertTrue(alphanumeric.contains(scalar),
                          "Suffix character '\(scalar)' is not alphanumeric")
        }
    }
}
