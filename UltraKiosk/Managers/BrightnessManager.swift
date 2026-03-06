import UIKit
import Combine

/// Manages screen brightness with restoration of original user settings
class BrightnessManager: ObservableObject {
    private var originalBrightness: CGFloat?
    private let settings = SettingsManager.shared
    
    /// Save the current system brightness and set app brightness
    func saveAndSetBrightness() {
        // Only save original brightness once
        if originalBrightness == nil {
            originalBrightness = UIScreen.main.brightness
            AppLogger.app.info("Saved original brightness: \(self.originalBrightness ?? 0)")
        }
        
        // Set to configured normal brightness
        UIScreen.main.brightness = CGFloat(settings.screenBrightnessNormal)
        AppLogger.app.debug("Set brightness to normal: \(self.settings.screenBrightnessNormal)")
    }
    
    /// Restore the original brightness that was saved
    func restoreOriginalBrightness() {
        guard let original = originalBrightness else {
            AppLogger.app.warning("No original brightness to restore")
            return
        }
        
        UIScreen.main.brightness = original
        AppLogger.app.info("Restored original brightness: \(original)")
    }
    
    /// Dim the screen (typically for screensaver mode)
    func dimScreen() {
        UIScreen.main.brightness = CGFloat(settings.screenBrightnessDimmed)
        AppLogger.app.debug("Dimmed screen to: \(self.settings.screenBrightnessDimmed)")
    }
    
    /// Set screen to normal kiosk brightness
    func setNormalBrightness() {
        UIScreen.main.brightness = CGFloat(settings.screenBrightnessNormal)
        AppLogger.app.debug("Set brightness to normal: \(self.settings.screenBrightnessNormal)")
    }
}
