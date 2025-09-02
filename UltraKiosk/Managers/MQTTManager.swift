import CocoaMQTT
import Combine
import Foundation
import UIKit

class MQTTManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var lastError: String?

    private var mqttClient: CocoaMQTT?
    private let settings = SettingsManager.shared
    private var batteryTimer: Timer?
    private var reconnectTimer: Timer?

    // Unique device identifiers
    private var deviceIdentifier: String {
        // Use iOS vendor identifier (persistent per app installation)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
    }

    private var deviceSerializedId: String {
        // Create a short, readable ID from the vendor identifier
        let fullId = deviceIdentifier
        let shortId = String(fullId.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased()
        return "ipad_\(shortId)"
    }

    private var deviceName: String {
        // Use iOS device name or fallback to model + identifier
        let deviceName = UIDevice.current.name
        if !deviceName.isEmpty && deviceName != "iPad" {
            return deviceName
        } else {
            let model = UIDevice.current.model
            let shortId = String(deviceIdentifier.replacingOccurrences(of: "-", with: "").prefix(6))
            return "\(model) \(shortId)"
        }
    }

    // Device information for Home Assistant Discovery
    private var deviceInfo: [String: Any] {
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let appVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        // Get additional device info
        let systemName = UIDevice.current.systemName
        let localizedModel = UIDevice.current.localizedModel

        return [
            "identifiers": [deviceSerializedId, deviceIdentifier],
            "name": deviceName,
            "model": "\(localizedModel) (\(deviceModel))",
            "manufacturer": "Apple",
            "sw_version": "\(systemName) \(systemVersion)",
            "hw_version": getDeviceModelIdentifier(),
        ]
    }

    init() {
        setupMQTTClient()

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            forName: .settingsChanged,
            object: nil,
            queue: .main
        ) { _ in
            self.reconnectIfNeeded()
        }
    }

    deinit {
        disconnect()
        batteryTimer?.invalidate()
        reconnectTimer?.invalidate()
    }

    // MARK: - Device Information Helpers
    private func getDeviceModelIdentifier() -> String {
        return UIDevice.current.model
    }

    // MARK: - MQTT Client Setup
    private func setupMQTTClient() {
        guard settings.enableMQTT,
            !settings.mqttBrokerIP.isEmpty,
            let port = UInt16(settings.mqttPort)
        else {
            updateConnectionStatus("MQTT deaktiviert oder nicht konfiguriert")
            return
        }

        // Use device-specific client ID
        let clientID = "\(deviceSerializedId)_\(Int(Date().timeIntervalSince1970))"
        mqttClient = CocoaMQTT(clientID: clientID, host: settings.mqttBrokerIP, port: port)

        guard let client = mqttClient else { return }

        // Client configuration
        client.username = settings.mqttUsername.isEmpty ? nil : settings.mqttUsername
        client.password = settings.mqttPassword.isEmpty ? nil : settings.mqttPassword
        client.keepAlive = 60
        client.cleanSession = true
        client.autoReconnect = true
        client.autoReconnectTimeInterval = 5

        // SSL/TLS configuration
        if settings.mqttUseTLS {
            client.enableSSL = true
            client.allowUntrustCACertificate = false
        }

        // Set delegates
        client.delegate = self

        // Last will and testament
        let willTopic = "\(settings.mqttTopicPrefix)/binary_sensor/\(deviceSerializedId)/status"
        client.willMessage = CocoaMQTTMessage(
            topic: willTopic, string: "offline", qos: .qos1, retained: true)

        updateConnectionStatus("Configured")

        AppLogger.mqtt.info("Device ID: \(self.deviceSerializedId)")
        AppLogger.mqtt.info("Device Name: \(self.deviceName)")
        AppLogger.mqtt.info("Vendor ID: \(self.deviceIdentifier)")
    }

    private func reconnectIfNeeded() {
        if settings.enableMQTT {
            disconnect()
            setupMQTTClient()
            if settings.enableMQTT && !settings.mqttBrokerIP.isEmpty {
                connect()
            }
        } else {
            disconnect()
        }
    }

    // MARK: - Connection Management
    func connect() {
        guard let client = mqttClient, settings.enableMQTT else { return }

        updateConnectionStatus("Verbindung wird hergestellt...")

        if !client.connect() {
            updateConnectionStatus("Connection error")
        }
    }

    func disconnect() {
        mqttClient?.disconnect()
        batteryTimer?.invalidate()
        batteryTimer = nil
        updateConnectionStatus("Disconnected")
    }

    private func updateConnectionStatus(_ status: String) {
        DispatchQueue.main.async {
            self.connectionStatus = status
            self.isConnected = (status == "Connected")

            AppLogger.mqtt.info("Status: \(status)")
        }
    }

    // MARK: - Home Assistant Discovery
    private func publishDiscoveryMessages() {
        guard isConnected else { return }

        // Battery Sensor Discovery
        publishBatterySensorDiscovery()

        // Screensaver Button Discovery
        publishScreensaverButtonDiscovery()

        // Status Binary Sensor Discovery
        publishStatusSensorDiscovery()

        // App Info Sensor Discovery
        publishAppInfoSensorDiscovery()
    }

    private func publishBatterySensorDiscovery() {
        let topic = "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/battery/config"

        let config: [String: Any] = [
            "name": "\(deviceName) Battery",
            "unique_id": "\(deviceSerializedId)_battery",
            "device_class": "battery",
            "unit_of_measurement": "%",
            "state_topic": "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/battery/state",
            "json_attributes_topic":
                "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/battery/attributes",
            "device": deviceInfo,
            "availability": [
                [
                    "topic":
                        "\(settings.mqttTopicPrefix)/binary_sensor/\(deviceSerializedId)/status",
                    "payload_available": "online",
                    "payload_not_available": "offline",
                ]
            ],
        ]

        publishJSON(topic: topic, payload: config, retain: true)
    }

    private func publishScreensaverButtonDiscovery() {
        let topic = "\(settings.mqttTopicPrefix)/button/\(deviceSerializedId)/screensaver/config"

        let config: [String: Any] = [
            "name": "\(deviceName) Screensaver",
            "unique_id": "\(deviceSerializedId)_screensaver_button",
            "command_topic":
                "\(settings.mqttTopicPrefix)/button/\(deviceSerializedId)/screensaver/set",
            "device": deviceInfo,
            "icon": "mdi:monitor-off",
            "availability": [
                [
                    "topic":
                        "\(settings.mqttTopicPrefix)/binary_sensor/\(deviceSerializedId)/status",
                    "payload_available": "online",
                    "payload_not_available": "offline",
                ]
            ],
        ]

        publishJSON(topic: topic, payload: config, retain: true)
    }

    private func publishStatusSensorDiscovery() {
        let topic = "\(settings.mqttTopicPrefix)/binary_sensor/\(deviceSerializedId)/status/config"

        let config: [String: Any] = [
            "name": "\(deviceName) Status",
            "unique_id": "\(deviceSerializedId)_status",
            "device_class": "connectivity",
            "state_topic": "\(settings.mqttTopicPrefix)/binary_sensor/\(deviceSerializedId)/status",
            "payload_on": "online",
            "payload_off": "offline",
            "device": deviceInfo,
        ]

        publishJSON(topic: topic, payload: config, retain: true)
    }

    private func publishAppInfoSensorDiscovery() {
        let topic = "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/app_info/config"

        let config: [String: Any] = [
            "name": "\(deviceName) App Info",
            "unique_id": "\(deviceSerializedId)_app_info",
            "state_topic":
                "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/app_info/state",
            "json_attributes_topic":
                "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/app_info/attributes",
            "icon": "mdi:information",
            "device": deviceInfo,
            "availability": [
                [
                    "topic":
                        "\(settings.mqttTopicPrefix)/binary_sensor/\(deviceSerializedId)/status",
                    "payload_available": "online",
                    "payload_not_available": "offline",
                ]
            ],
        ]

        publishJSON(topic: topic, payload: config, retain: true)
    }

    // MARK: - State Publishing
    private func startPeriodicUpdates() {
        // Publish initial states
        publishDeviceStatus()
        publishBatteryLevel()
        publishAppInfo()

        // Setup periodic battery updates
        batteryTimer = Timer.scheduledTimer(
            withTimeInterval: settings.mqttBatteryUpdateInterval, repeats: true
        ) { _ in
            self.publishBatteryLevel()
        }
    }

    private func publishDeviceStatus() {
        let topic = "\(settings.mqttTopicPrefix)/binary_sensor/\(deviceSerializedId)/status"
        publish(topic: topic, payload: "online", retain: true)
    }

    func publishBatteryLevel() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState

        // Battery level (0-100%)
        let batteryPercentage = batteryLevel >= 0 ? Int(batteryLevel * 100) : 0
        let stateTopic = "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/battery/state"
        publish(topic: stateTopic, payload: String(batteryPercentage))

        // Battery attributes with more details
        let batteryStateString = batteryStateToString(batteryState)
        let attributes: [String: Any] = [
            "battery_state": batteryStateString,
            "is_charging": batteryState == .charging || batteryState == .full,
            "battery_level": batteryPercentage,
            "low_power_mode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "last_updated": ISO8601DateFormatter().string(from: Date()),
        ]

        let attributesTopic =
            "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/battery/attributes"
        publishJSON(topic: attributesTopic, payload: attributes)

        AppLogger.mqtt.debug(
            "Published battery level: \(batteryPercentage)% (\(batteryStateString))")
    }

    private func publishAppInfo() {
        let appVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let uptime = ProcessInfo.processInfo.systemUptime

        let stateTopic = "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/app_info/state"
        publish(topic: stateTopic, payload: "active")

        let attributes: [String: Any] = [
            "app_version": appVersion,
            "build_number": buildNumber,
            "uptime_seconds": Int(uptime),
            "device_model": UIDevice.current.model,
            "device_name": UIDevice.current.name,
            "ios_version": UIDevice.current.systemVersion,
            "system_name": UIDevice.current.systemName,
            "device_identifier": getDeviceModelIdentifier(),
            "vendor_id": deviceIdentifier,
            "kiosk_mode": true,
            "voice_activation_enabled": settings.enableVoiceActivation,
            "screensaver_timeout": settings.screensaverTimeout,
            "last_updated": ISO8601DateFormatter().string(from: Date()),
        ]

        let attributesTopic =
            "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/app_info/attributes"
        publishJSON(topic: attributesTopic, payload: attributes)
    }

    // MARK: - Command Handling
    private func subscribeToCommands() {
        guard let client = mqttClient else { return }

        // Subscribe to screensaver button
        let screensaverTopic =
            "\(settings.mqttTopicPrefix)/button/\(deviceSerializedId)/screensaver/set"
        client.subscribe(screensaverTopic, qos: .qos1)

        AppLogger.mqtt.info("Subscribed to \(screensaverTopic)")
    }

    private func handleIncomingMessage(_ message: CocoaMQTTMessage) {
        let topic = message.topic
        let payload = message.string ?? ""

        AppLogger.mqtt.debug("Received message on \(topic): \(payload)")

        // Handle screensaver button
        if topic.contains("/screensaver/set") {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .mqttScreensaverActivated, object: nil)
            }
        }
    }

    // MARK: - Publishing Helpers
    private func publish(
        topic: String, payload: String, qos: CocoaMQTTQoS = .qos0, retain: Bool = false
    ) {
        guard let client = mqttClient, isConnected else { return }

        let message = CocoaMQTTMessage(topic: topic, string: payload, qos: qos, retained: retain)
        client.publish(message)

        AppLogger.mqtt.debug("Published to \(topic): \(payload)")
    }

    private func publishJSON(
        topic: String, payload: [String: Any], qos: CocoaMQTTQoS = .qos0, retain: Bool = false
    ) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            publish(topic: topic, payload: jsonString, qos: qos, retain: retain)
        } catch {
            AppLogger.mqtt.error(
                "Failed to serialize JSON for \(topic): \(String(describing: error))")
        }
    }

    // MARK: - Helper Functions
    private func batteryStateToString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        @unknown default:
            return "unknown"
        }
    }

    // MARK: - Public Interface
    func getDeviceInfo() -> [String: String] {
        return [
            "device_id": deviceSerializedId,
            "device_name": deviceName,
            "vendor_id": deviceIdentifier,
            "model_identifier": getDeviceModelIdentifier(),
        ]
    }

    func triggerScreensaver() {
        let topic = "\(settings.mqttTopicPrefix)/button/\(deviceSerializedId)/screensaver/triggered"
        publish(topic: topic, payload: "triggered")
    }

    func publishCustomEvent(_ eventType: String, data: [String: Any] = [:]) {
        let topic = "\(settings.mqttTopicPrefix)/sensor/\(deviceSerializedId)/events"

        var eventData = data
        eventData["event_type"] = eventType
        eventData["device_id"] = deviceSerializedId
        eventData["timestamp"] = ISO8601DateFormatter().string(from: Date())

        publishJSON(topic: topic, payload: eventData)
    }
}

// MARK: - CocoaMQTTDelegate
extension MQTTManager: CocoaMQTTDelegate {

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            updateConnectionStatus("Connected")

            // Publish discovery messages
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.publishDiscoveryMessages()
                self.subscribeToCommands()
                self.startPeriodicUpdates()
            }
        } else {
            updateConnectionStatus("Connection refused: \(ack)")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didDisconnectWith err: Error?) {
        batteryTimer?.invalidate()
        batteryTimer = nil

        if let error = err {
            updateConnectionStatus("Connection lost: \(error.localizedDescription)")
            lastError = error.localizedDescription
        } else {
            updateConnectionStatus("Disconnected")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        handleIncomingMessage(message)
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        // Message published successfully
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        AppLogger.mqtt.debug("Published message ack id=\(id)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        AppLogger.mqtt.info("Subscribed successfully: \(success)")
        if !failed.isEmpty {
            AppLogger.mqtt.error("Failed subscriptions: \(failed)")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        AppLogger.mqtt.info("Unsubscribed topics: \(topics)")
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
        // Keepalive ping
    }

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        // Keepalive pong
    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        // Handle disconnect
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let mqttScreensaverActivated = Notification.Name("MQTTScreensaverActivated")
    static let mqttConnected = Notification.Name("MQTTConnected")
    static let mqttDisconnected = Notification.Name("MQTTDisconnected")
}
