import SwiftUI
import Combine

class KioskManager: ObservableObject {
    @Published var isScreensaverActive = false
    @Published var inactivityTimer: Timer?
    
    private let settings = SettingsManager.shared
    private let brightnessManager = BrightnessManager()
    private var inactivityTimeout: TimeInterval = 60.0 // 30 seconds for demo
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        inactivityTimeout = settings.screensaverTimeout
    }
    
    func startInactivityMonitoring() {
        resetInactivityTimer()
    }
    
    func updateTimeout(_ newTimeout: TimeInterval) {
        inactivityTimeout = newTimeout
        if !isScreensaverActive {
            resetInactivityTimer()
        }
    }
    
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        
        if !isScreensaverActive {
            inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.activateScreensaver()
                }
            }
        }
    }
    
    func activateScreensaver() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isScreensaverActive = true
        }
        
        // Dim screen using brightness manager
        brightnessManager.dimScreen()
    }
    
    func exitScreensaver() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isScreensaverActive = false
        }
        
        // Restore screen brightness using brightness manager
        brightnessManager.setNormalBrightness()
        
        resetInactivityTimer()
    }
    
    func handleUserActivity() {
        if isScreensaverActive {
            exitScreensaver()
        } else {
            resetInactivityTimer()
        }
    }
}
