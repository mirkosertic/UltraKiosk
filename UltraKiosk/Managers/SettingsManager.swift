
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - App Groups Container
    private let appGroupID = "group.de.mirkosertic.UltraKiosk.settings"
    private var userDefaults: UserDefaults {
        return UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    }
    
    // MARK: - Published Settings
    @Published var homeAssistantIP: String = "homeassistant.local" {
        didSet { save() }
    }
    
    @Published var homeAssistantPort: String = "8123" {
        didSet { save() }
    }
    
    @Published var accessToken: String = "" {
        didSet { save() }
    }
    
    @Published var useHTTPS: Bool = false {
        didSet { save() }
    }
    
    @Published var mqttBrokerIP: String = "homeassistant.local" {
        didSet { save() }
    }
    
    @Published var mqttPort: String = "1883" {
        didSet { save() }
    }
    
    @Published var mqttUsername: String = "homeassistant" {
        didSet { save() }
    }
    
    @Published var mqttPassword: String = "" {
        didSet { save() }
    }
    
    @Published var mqttUseTLS: Bool = false {
        didSet { save() }
    }
    
    @Published var mqttTopicPrefix: String = "homeassistant" {
        didSet { save() }
    }
    
    @Published var enableMQTT: Bool = true {
        didSet { save() }
    }
    
    @Published var mqttBatteryUpdateInterval: Double = 60.0 { // seconds
        didSet { save() }
    }
    
    @Published var screensaverTimeout: Double = 60.0 { // 1 minutes default
        didSet { save() }
    }
    
    @Published var screenBrightnessDimmed: Double = 0.2 {
        didSet { save() }
    }
    
    @Published var screenBrightnessNormal: Double = 1.0 {
        didSet { save() }
    }
    
    @Published var enableVoiceActivation: Bool = false {
        didSet { save() }
    }
    
    @Published var kioskURL: String = "" {
        didSet { save() }
    }
    
    @Published var faceDetectionInterval: Double = 1.0 { // seconds between detections
        didSet { save() }
    }
    
    // Voice pipeline settings
    @Published var voiceSampleRate: Int = 16000 {
        didSet { save() }
    }
    
    @Published var voiceTimeout: Int = 10 {
        didSet { save() }
    }
    
    @Published var voiceNoiseSuppressionLevel: Int = 2 {
        didSet { save() }
    }
    
    @Published var voiceAutoGainDbfs: Int = 20 {
        didSet { save() }
    }
    
    @Published var voiceVolumeMultiplier: Double = 1.5 {
        didSet { save() }
    }
    
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
        // Voice pipeline keys
        static let voiceSampleRate = "voiceSampleRate"
        static let voiceTimeout = "voiceTimeout"
        static let voiceNoiseSuppressionLevel = "voiceNoiseSuppressionLevel"
        static let voiceAutoGainDbfs = "voiceAutoGainDbfs"
        static let voiceVolumeMultiplier = "voiceVolumeMultiplier"
    }
    
    private init() {
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
        accessToken = defaults.string(forKey: Keys.accessToken) ?? ""
        useHTTPS = defaults.bool(forKey: Keys.useHTTPS)
        
        // MQTT Settings
        mqttBrokerIP = defaults.string(forKey: Keys.mqttBrokerIP) ?? "192.168.1.100"
        mqttPort = defaults.string(forKey: Keys.mqttPort) ?? "1883"
        mqttUsername = defaults.string(forKey: Keys.mqttUsername) ?? "homeassistant"
        mqttPassword = defaults.string(forKey: Keys.mqttPassword) ?? ""
        mqttUseTLS = defaults.bool(forKey: Keys.mqttUseTLS)
        mqttTopicPrefix = defaults.string(forKey: Keys.mqttTopicPrefix) ?? "homeassistant"
        enableMQTT = defaults.object(forKey: Keys.enableMQTT) != nil ? defaults.bool(forKey: Keys.enableMQTT) : true
        mqttBatteryUpdateInterval = defaults.double(forKey: Keys.mqttBatteryUpdateInterval) != 0
        ? defaults.double(forKey: Keys.mqttBatteryUpdateInterval) : 60.0
        
        screensaverTimeout = defaults.double(forKey: Keys.screensaverTimeout) != 0
        ? defaults.double(forKey: Keys.screensaverTimeout) : 60.0
        screenBrightnessDimmed = defaults.double(forKey: Keys.screenBrightnessDimmed) != 0
        ? defaults.double(forKey: Keys.screenBrightnessDimmed) : 0.2
        screenBrightnessNormal = defaults.double(forKey: Keys.screenBrightnessNormal) != 0
        ? defaults.double(forKey: Keys.screenBrightnessNormal) : 1.0
        enableVoiceActivation = defaults.object(forKey: Keys.enableVoiceActivation) != nil
        ? defaults.bool(forKey: Keys.enableVoiceActivation) : false
        kioskURL = defaults.string(forKey: Keys.kioskURL) ?? "http://homeassistant.local:8123/anzeige-flur/0?kios=true"
        faceDetectionInterval = defaults.double(forKey: Keys.faceDetectionInterval) != 0
        ? defaults.double(forKey: Keys.faceDetectionInterval) : 1.0
        
        // Voice pipeline settings
        let sr = defaults.integer(forKey: Keys.voiceSampleRate)
        voiceSampleRate = sr != 0 ? sr : 16000
        let to = defaults.integer(forKey: Keys.voiceTimeout)
        voiceTimeout = to != 0 ? to : 10
        let ns = defaults.integer(forKey: Keys.voiceNoiseSuppressionLevel)
        voiceNoiseSuppressionLevel = ns != 0 ? ns : 2
        // 0 could be a valid value for auto gain, so we check object existence
        if defaults.object(forKey: Keys.voiceAutoGainDbfs) != nil {
            voiceAutoGainDbfs = defaults.integer(forKey: Keys.voiceAutoGainDbfs)
        } else {
            voiceAutoGainDbfs = 20
        }
        let vm = defaults.double(forKey: Keys.voiceVolumeMultiplier)
        voiceVolumeMultiplier = vm != 0 ? vm : 1.5
    }
    
    private func save() {
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
        defaults.set(voiceNoiseSuppressionLevel, forKey: Keys.voiceNoiseSuppressionLevel)
        defaults.set(voiceAutoGainDbfs, forKey: Keys.voiceAutoGainDbfs)
        defaults.set(voiceVolumeMultiplier, forKey: Keys.voiceVolumeMultiplier)
        
        defaults.synchronize()
        
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
            // Voice pipeline
            "voiceSampleRate": voiceSampleRate,
            "voiceTimeout": voiceTimeout,
            "voiceNoiseSuppressionLevel": voiceNoiseSuppressionLevel,
            "voiceAutoGainDbfs": voiceAutoGainDbfs,
            "voiceVolumeMultiplier": voiceVolumeMultiplier,
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
        
        // Voice pipeline
        if let v = settings["voiceSampleRate"] as? Int { voiceSampleRate = v }
        if let v = settings["voiceTimeout"] as? Int { voiceTimeout = v }
        if let v = settings["voiceNoiseSuppressionLevel"] as? Int { voiceNoiseSuppressionLevel = v }
        if let v = settings["voiceAutoGainDbfs"] as? Int { voiceAutoGainDbfs = v }
        if let v = settings["voiceVolumeMultiplier"] as? Double { voiceVolumeMultiplier = v }
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
        screenBrightnessNormal = 1.0
        enableVoiceActivation = true
        kioskURL = ""
        faceDetectionInterval = 1.0
        
        // Voice pipeline defaults
        voiceSampleRate = 16000
        voiceTimeout = 10
        voiceNoiseSuppressionLevel = 2
        voiceAutoGainDbfs = 20
        voiceVolumeMultiplier = 1.5
    }
}
