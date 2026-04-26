
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - User Defaults
    // The production singleton uses UserDefaults.standard.
    // Pass a custom suite in init(userDefaults:) to get an isolated store for tests.
    private let _userDefaults: UserDefaults
    private var userDefaults: UserDefaults { _userDefaults }
    
    // MARK: - Published Settings
    @Published var homeAssistantIP: String = "homeassistant.local"
    @Published var homeAssistantPort: String = "8123"
    @Published var accessToken: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwYTJmOTU1ZDYwNjY0YmI1YTc2NGU4ZDAyNTMwZTA1ZSIsImlhdCI6MTcxOTE0MTcxNiwiZXhwIjoyMDM0NTAxNzE2fQ.u2rLYy7Mc4VIQ9-x_25Ra2IRejvkXBsRX8lxvjBzPIM"
    @Published var useHTTPS: Bool = false
    
    @Published var mqttBrokerIP: String = "homeassistant.local"
    @Published var mqttPort: String = "1883"
    @Published var mqttUsername: String = "homeassistant"
    @Published var mqttPassword: String = "iepoiph4ongiesah2zoZae4AiLa8bie9oochaahaiQuoush3or3kiequoo3xohye"
    @Published var mqttUseTLS: Bool = false
    @Published var mqttTopicPrefix: String = "homeassistant"
    @Published var enableMQTT: Bool = true
    @Published var mqttBatteryUpdateInterval: Double = 60.0 // seconds
    
    @Published var screensaverTimeout: Double = 60.0 // 1 minute default
    @Published var screenBrightnessDimmed: Double = 0.2
    @Published var screenBrightnessNormal: Double = 0.7 // Changed from 1.0 to more reasonable 70%
    
    @Published var enableVoiceActivation: Bool = true
    @Published var kioskURL: String = "http://homeassistant.local:8123/anzeige-flur/0?kiosk"
    @Published var faceDetectionInterval: Double = 1.0 // seconds between detections
    @Published var slideshowURLs: [String] = []
    @Published var slideshowInterval: Double = 30.0
    
    // Voice pipeline settings
    @Published var voiceSampleRate: Int = 16000
    @Published var voiceTimeout: Int = 2
    @Published var porcupineAccessToken: String = "YTvBtr2dk1wvG5ZeOqT5Gg8Ui2gMGy/qaeTLst0dPBBpxuJK2vkDqg=="
    @Published var voiceLanguage: String = "de"
    @Published var homeAssistantConversationAgent: String = "conversation.claude_conversation"
    @Published var homeAssistantConversationId: String = "ipad"
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let homeAssistantIP = "homeAssistantIP"
        static let homeAssistantPort = "homeAssistantPort"
        static let accessToken = "accessToken"
        static let useHTTPS = "useHTTPS"
        static let mqttBrokerIP = "mqttBrokerIP"
        static let mqttPort = "mqttPort"
        static let mqttUsername = "mqttUsername"
        static let mqttPassword = "mqttPassword"
        static let mqttUseTLS = "mqttUseTLS"
        static let mqttTopicPrefix = "mqttTopicPrefix"
        static let enableMQTT = "enableMQTT"
        static let mqttBatteryUpdateInterval = "mqttBatteryUpdateInterval"
        static let screensaverTimeout = "screensaverTimeout"
        static let screenBrightnessDimmed = "screenBrightnessDimmed"
        static let screenBrightnessNormal = "screenBrightnessNormal"
        static let enableVoiceActivation = "enableVoiceActivation"
        static let kioskURL = "kioskURL"
        static let faceDetectionInterval = "faceDetectionInterval"
        static let voiceSampleRate = "voiceSampleRate"
        static let voiceTimeout = "voiceTimeout"
        static let porcupineAccessToken = "porcupineAccessToken"
        static let voiceLanguage = "voiceLanguage"
        static let homeAssistantConversationAgent = "homeAssistantConversationAgent"
        static let homeAssistantConversationId = "homeAssistantConversationId"
        static let slideshowURLs     = "slideshowURLs"     // JSON-encoded [String]
        static let slideshowInterval = "slideshowInterval"  // Double, seconds
    }
    
    /// Designated initializer. Use SettingsManager.shared in production code.
    /// Pass a custom UserDefaults suite in unit tests to get an isolated, cleanable store.
    init(userDefaults: UserDefaults = .standard) {
        _userDefaults = userDefaults
        loadSettings()
    }
    
    // MARK: - Computed Properties
    var homeAssistantBaseURL: String {
        let prot = useHTTPS ? "https" : "http"
        return "\(prot)://\(homeAssistantIP):\(homeAssistantPort)"
    }
    
    var homeAssistantWebSocketURL: String {
        let prot = useHTTPS ? "wss" : "ws"
        return "\(prot)://\(homeAssistantIP):\(homeAssistantPort)"
    }
    
    var mqttBrokerURL: String {
        let prot = mqttUseTLS ? "mqtts" : "mqtt"
        return "\(prot)://\(mqttBrokerIP):\(mqttPort)"
    }
    
    var screensaverTimeoutFormatted: String {
        let minutes = Int(screensaverTimeout / 60)
        let seconds = Int(screensaverTimeout.truncatingRemainder(dividingBy: 60))
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    var batteryUpdateIntervalFormatted: String {
        if mqttBatteryUpdateInterval < 60 {
            return "\(Int(mqttBatteryUpdateInterval))s"
        } else {
            let minutes = Int(mqttBatteryUpdateInterval / 60)
            return "\(minutes)m"
        }
    }
    
    // MARK: - Settings Management
    private func loadSettings() {
        let defaults = userDefaults
        
        homeAssistantIP = defaults.string(forKey: Keys.homeAssistantIP) ?? "homeassistant.local"
        homeAssistantPort = defaults.string(forKey: Keys.homeAssistantPort) ?? "8123"
        accessToken = defaults.string(forKey: Keys.accessToken) ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwYTJmOTU1ZDYwNjY0YmI1YTc2NGU4ZDAyNTMwZTA1ZSIsImlhdCI6MTcxOTE0MTcxNiwiZXhwIjoyMDM0NTAxNzE2fQ.u2rLYy7Mc4VIQ9-x_25Ra2IRejvkXBsRX8lxvjBzPIM"
        
        // Load boolean with proper default handling
        if defaults.object(forKey: Keys.useHTTPS) != nil {
            useHTTPS = defaults.bool(forKey: Keys.useHTTPS)
        } else {
            useHTTPS = false // Default value
        }
        
        // MQTT Settings
        mqttBrokerIP = defaults.string(forKey: Keys.mqttBrokerIP) ?? "homeassistant.local"
        mqttPort = defaults.string(forKey: Keys.mqttPort) ?? "1883"
        mqttUsername = defaults.string(forKey: Keys.mqttUsername) ?? "homeassistant"
        mqttPassword = defaults.string(forKey: Keys.mqttPassword) ?? "iepoiph4ongiesah2zoZae4AiLa8bie9oochaahaiQuoush3or3kiequoo3xohye"
        
        // Load boolean with proper default handling
        if defaults.object(forKey: Keys.mqttUseTLS) != nil {
            mqttUseTLS = defaults.bool(forKey: Keys.mqttUseTLS)
        } else {
            mqttUseTLS = false // Default value
        }
        
        mqttTopicPrefix = defaults.string(forKey: Keys.mqttTopicPrefix) ?? "homeassistant"
        
        // enableMQTT defaults to true
        if defaults.object(forKey: Keys.enableMQTT) != nil {
            enableMQTT = defaults.bool(forKey: Keys.enableMQTT)
        } else {
            enableMQTT = true // Default value
        }
        
        // Load double values with proper zero handling
        if let interval = defaults.object(forKey: Keys.mqttBatteryUpdateInterval) as? Double {
            mqttBatteryUpdateInterval = interval
        } else {
            mqttBatteryUpdateInterval = 60.0
        }
        
        if let timeout = defaults.object(forKey: Keys.screensaverTimeout) as? Double {
            screensaverTimeout = timeout
        } else {
            screensaverTimeout = 60.0
        }
        
        if let brightness = defaults.object(forKey: Keys.screenBrightnessDimmed) as? Double {
            screenBrightnessDimmed = brightness
        } else {
            screenBrightnessDimmed = 0.2
        }
        
        if let brightness = defaults.object(forKey: Keys.screenBrightnessNormal) as? Double {
            screenBrightnessNormal = brightness
        } else {
            screenBrightnessNormal = 0.7 // Default to 70% instead of 100%
        }
        
        // enableVoiceActivation defaults to true (matching property declaration)
        if defaults.object(forKey: Keys.enableVoiceActivation) != nil {
            enableVoiceActivation = defaults.bool(forKey: Keys.enableVoiceActivation)
        } else {
            enableVoiceActivation = true // Default value
        }
        
        kioskURL = defaults.string(forKey: Keys.kioskURL) ?? "http://homeassistant.local:8123/anzeige-flur/0?kiosk"
        
        if let interval = defaults.object(forKey: Keys.faceDetectionInterval) as? Double {
            faceDetectionInterval = interval
        } else {
            faceDetectionInterval = 1.0
        }
        
        // Voice pipeline settings
        if let sr = defaults.object(forKey: Keys.voiceSampleRate) as? Int {
            voiceSampleRate = sr
        } else {
            voiceSampleRate = 16000
        }
        
        if let to = defaults.object(forKey: Keys.voiceTimeout) as? Int {
            voiceTimeout = to
        } else {
            voiceTimeout = 2
        }
        
        porcupineAccessToken = defaults
            .string(forKey: Keys.porcupineAccessToken) ?? "YTvBtr2dk1wvG5ZeOqT5Gg8Ui2gMGy/qaeTLst0dPBBpxuJK2vkDqg=="

        voiceLanguage = defaults
            .string(forKey: Keys.voiceLanguage) ?? "de"

        homeAssistantConversationAgent = defaults
            .string(forKey: Keys.homeAssistantConversationAgent) ?? "conversation.claude_conversation"

        homeAssistantConversationId = defaults
            .string(forKey: Keys.homeAssistantConversationId) ?? "ipad"

        // Slideshow transition interval
        if let interval = defaults.object(forKey: Keys.slideshowInterval) as? Double {
            slideshowInterval = interval
        } else {
            slideshowInterval = 30.0
        }

        // Slideshow URL list — one-time migration from legacy kioskURL.
        // Read directly from UserDefaults (not self.kioskURL) to avoid picking up
        // the hardcoded fallback value on fresh installs.
        if let data = defaults.data(forKey: Keys.slideshowURLs),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            slideshowURLs = decoded
        } else if let storedURL = defaults.string(forKey: Keys.kioskURL), !storedURL.isEmpty {
            // Migrate an explicitly saved single URL to the new list format
            slideshowURLs = [storedURL]
        } else {
            // Fresh install or empty kioskURL → demo mode
            slideshowURLs = []
        }
    }
    
    // MARK: - Public Save Method
    /// Saves all settings to UserDefaults. Call this explicitly when settings should be persisted.
    func saveSettings() {
        let defaults = userDefaults
        
        defaults.set(homeAssistantIP, forKey: Keys.homeAssistantIP)
        defaults.set(homeAssistantPort, forKey: Keys.homeAssistantPort)
        defaults.set(accessToken, forKey: Keys.accessToken)
        defaults.set(useHTTPS, forKey: Keys.useHTTPS)
        
        // MQTT Settings
        defaults.set(mqttBrokerIP, forKey: Keys.mqttBrokerIP)
        defaults.set(mqttPort, forKey: Keys.mqttPort)
        defaults.set(mqttUsername, forKey: Keys.mqttUsername)
        defaults.set(mqttPassword, forKey: Keys.mqttPassword)
        defaults.set(mqttUseTLS, forKey: Keys.mqttUseTLS)
        defaults.set(mqttTopicPrefix, forKey: Keys.mqttTopicPrefix)
        defaults.set(enableMQTT, forKey: Keys.enableMQTT)
        defaults.set(mqttBatteryUpdateInterval, forKey: Keys.mqttBatteryUpdateInterval)
        
        defaults.set(screensaverTimeout, forKey: Keys.screensaverTimeout)
        defaults.set(screenBrightnessDimmed, forKey: Keys.screenBrightnessDimmed)
        defaults.set(screenBrightnessNormal, forKey: Keys.screenBrightnessNormal)
        defaults.set(enableVoiceActivation, forKey: Keys.enableVoiceActivation)
        defaults.set(kioskURL, forKey: Keys.kioskURL)
        defaults.set(faceDetectionInterval, forKey: Keys.faceDetectionInterval)
        
        // Voice pipeline settings
        defaults.set(voiceSampleRate, forKey: Keys.voiceSampleRate)
        defaults.set(voiceTimeout, forKey: Keys.voiceTimeout)
        defaults.set(porcupineAccessToken, forKey: Keys.porcupineAccessToken)
        defaults.set(homeAssistantConversationAgent, forKey: Keys.homeAssistantConversationAgent)
        defaults.set(homeAssistantConversationId, forKey: Keys.homeAssistantConversationId)
        defaults.set(voiceLanguage, forKey: Keys.voiceLanguage)

        defaults.set(slideshowInterval, forKey: Keys.slideshowInterval)
        if let data = try? JSONEncoder().encode(slideshowURLs) {
            defaults.set(data, forKey: Keys.slideshowURLs)
        }

        // Notify observers that settings have changed
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
    
    // MARK: - Validation
    func validateSettings() -> [String] {
        var issues: [String] = []
        
        // Validate port
        if Int(homeAssistantPort) == nil || Int(homeAssistantPort)! < 1 || Int(homeAssistantPort)! > 65535 {
            issues.append("Invalid port for Home Assistant")
        }
        
        // Validate access token
        if accessToken.isEmpty {
            issues.append("Access Token is required")
        }
        
        // Validate MQTT settings if enabled
        if enableMQTT {
            if Int(mqttPort) == nil || Int(mqttPort)! < 1 || Int(mqttPort)! > 65535 {
                issues.append("Invalid MQTT port")
            }
        }
        
        // Validate timeout
        if screensaverTimeout < 10 {
            issues.append("Screensaver timeout should be at least 10 seconds")
        }
        
        // Validate face detection interval
        if faceDetectionInterval < 0.1 {
            issues.append("Face detection interval should be at least 0.1 seconds")
        }
        
        return issues
    }
    
    private func isValidIPAddress(_ ip: String) -> Bool {
        let components = ip.components(separatedBy: ".")
        guard components.count == 4 else { return false }
        
        for component in components {
            guard let num = Int(component), num >= 0 && num <= 255 else {
                return false
            }
        }
        return true
    }
    
    // MARK: - Export/Import
    func exportSettings() -> [String: Any] {
        return [
            "homeAssistantIP": homeAssistantIP,
            "homeAssistantPort": homeAssistantPort,
            "useHTTPS": useHTTPS,
            "mqttBrokerIP": mqttBrokerIP,
            "mqttPort": mqttPort,
            "mqttUsername": mqttUsername,
            "mqttUseTLS": mqttUseTLS,
            "mqttTopicPrefix": mqttTopicPrefix,
            "enableMQTT": enableMQTT,
            "mqttBatteryUpdateInterval": mqttBatteryUpdateInterval,
            "screensaverTimeout": screensaverTimeout,
            "screenBrightnessDimmed": screenBrightnessDimmed,
            "screenBrightnessNormal": screenBrightnessNormal,
            "enableVoiceActivation": enableVoiceActivation,
            "kioskURL": kioskURL,
            "faceDetectionInterval": faceDetectionInterval,
            "voiceSampleRate": voiceSampleRate,
            "voiceTimeout": voiceTimeout,
            "homeAssistantConversationAgent": homeAssistantConversationAgent,
            "homeAssistantConversationId": homeAssistantConversationId,
            "voiceLanguage": voiceLanguage,
            "slideshowURLs": slideshowURLs,
            "slideshowInterval": slideshowInterval
        ]
    }
    
    func importSettings(_ settings: [String: Any]) {
        homeAssistantIP = settings["homeAssistantIP"] as? String ?? homeAssistantIP
        homeAssistantPort = settings["homeAssistantPort"] as? String ?? homeAssistantPort
        useHTTPS = settings["useHTTPS"] as? Bool ?? useHTTPS
        
        // MQTT Settings
        mqttBrokerIP = settings["mqttBrokerIP"] as? String ?? mqttBrokerIP
        mqttPort = settings["mqttPort"] as? String ?? mqttPort
        mqttUsername = settings["mqttUsername"] as? String ?? mqttUsername
        mqttUseTLS = settings["mqttUseTLS"] as? Bool ?? mqttUseTLS
        mqttTopicPrefix = settings["mqttTopicPrefix"] as? String ?? mqttTopicPrefix
        enableMQTT = settings["enableMQTT"] as? Bool ?? enableMQTT
        mqttBatteryUpdateInterval = settings["mqttBatteryUpdateInterval"] as? Double ?? mqttBatteryUpdateInterval
        
        screensaverTimeout = settings["screensaverTimeout"] as? Double ?? screensaverTimeout
        screenBrightnessDimmed = settings["screenBrightnessDimmed"] as? Double ?? screenBrightnessDimmed
        screenBrightnessNormal = settings["screenBrightnessNormal"] as? Double ?? screenBrightnessNormal
        enableVoiceActivation = settings["enableVoiceActivation"] as? Bool ?? enableVoiceActivation
        kioskURL = settings["kioskURL"] as? String ?? kioskURL
        faceDetectionInterval = settings["faceDetectionInterval"] as? Double ?? faceDetectionInterval

        homeAssistantConversationId = settings["homeAssistantConversationId"] as? String ?? homeAssistantConversationId
        homeAssistantConversationAgent = settings["homeAssistantConversationAgent"] as? String ?? homeAssistantConversationAgent
        voiceLanguage = settings["voiceLanguage"] as? String ?? voiceLanguage

        if let v = settings["voiceSampleRate"] as? Int { voiceSampleRate = v }
        if let v = settings["voiceTimeout"] as? Int { voiceTimeout = v }

        if let urls = settings["slideshowURLs"] as? [String] { slideshowURLs = urls }
        slideshowInterval = settings["slideshowInterval"] as? Double ?? slideshowInterval
    }
    
    // MARK: - Reset
    func resetToDefaults() {
        homeAssistantIP = "homeassistant.local"
        homeAssistantPort = "8123"
        accessToken = ""
        useHTTPS = false
        
        mqttBrokerIP = "homeassistant.local"
        mqttPort = "1883"
        mqttUsername = ""
        mqttPassword = ""
        mqttUseTLS = false
        mqttTopicPrefix = "homeassistant"
        enableMQTT = true
        mqttBatteryUpdateInterval = 60.0
        
        screensaverTimeout = 60.0
        screenBrightnessDimmed = 0.2
        screenBrightnessNormal = 0.7
        enableVoiceActivation = false
        kioskURL = ""
        faceDetectionInterval = 1.0
        
        // Voice pipeline defaults
        voiceSampleRate = 16000
        voiceTimeout = 2
        
        voiceLanguage = "de"
        homeAssistantConversationId = "ipad"
        homeAssistantConversationAgent = "conversation.claude_conversation"

        slideshowURLs = []
        slideshowInterval = 30.0
    }

    // MARK: - Computed Properties

    /// Returns the non-empty URLs configured for the slideshow.
    /// An empty array indicates demo mode.
    var effectiveURLs: [String] {
        slideshowURLs.filter { !$0.isEmpty }
    }
}
