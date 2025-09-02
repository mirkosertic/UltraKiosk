import os

enum LogCategory: String {
	case webView = "WebView"
	case homeAssistant = "HomeAssistant"
	case audio = "Audio"
	case mqtt = "MQTT"
	case app = "App"
}

struct AppLogger {
	static let subsystem = "de.mirkosertic.UltraKiosk"
	
	static let webView = Logger(subsystem: subsystem, category: LogCategory.webView.rawValue)
	static let homeAssistant = Logger(subsystem: subsystem, category: LogCategory.homeAssistant.rawValue)
	static let audio = Logger(subsystem: subsystem, category: LogCategory.audio.rawValue)
	static let mqtt = Logger(subsystem: subsystem, category: LogCategory.mqtt.rawValue)
	static let app = Logger(subsystem: subsystem, category: LogCategory.app.rawValue)
} 