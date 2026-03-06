import os

enum LogCategory: String {
    case webView = "WebView"
    case homeAssistant = "HomeAssistant"
    case audio = "Audio"
    case mqtt = "MQTT"
    case app = "App"
    case speech = "Speech"
}

struct AppLogger {
    static let subsystem = "de.mirkosertic.UltraKiosk"
    
    #if DEBUG
    // In debug builds, enable all logging levels
    static let logLevel: OSLogType = .debug
    #else
    // In release builds, only log info and above (reduces performance impact)
    static let logLevel: OSLogType = .default
    #endif
    
    static let webView = Logger(subsystem: subsystem, category: LogCategory.webView.rawValue)
    static let homeAssistant = Logger(subsystem: subsystem, category: LogCategory.homeAssistant.rawValue)
    static let audio = Logger(subsystem: subsystem, category: LogCategory.audio.rawValue)
    static let mqtt = Logger(subsystem: subsystem, category: LogCategory.mqtt.rawValue)
    static let app = Logger(subsystem: subsystem, category: LogCategory.app.rawValue)
    static let speech = Logger(subsystem: subsystem, category: LogCategory.speech.rawValue)
}

// MARK: - Conditional Logging Extensions
extension Logger {
    /// Log debug messages only in DEBUG builds
    func debugConditional(_ message: String) {
        #if DEBUG
        self.debug("\(message)")
        #endif
    }
    
    /// Log info messages (always logged)
    func infoConditional(_ message: String) {
        self.info("\(message)")
    }
    
    /// Log warnings (always logged)
    func warningConditional(_ message: String) {
        self.warning("\(message)")
    }
    
    /// Log errors (always logged)
    func errorConditional(_ message: String) {
        self.error("\(message)")
    }
}
