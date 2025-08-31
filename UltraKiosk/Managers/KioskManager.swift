import SwiftUI
import Combine

class KioskManager: ObservableObject {
    @Published var isScreensaverActive = false
    @Published var inactivityTimer: Timer?
    
    private let inactivityTimeout: TimeInterval = 60.0 // 30 seconds for demo
    private var cancellables = Set<AnyCancellable>()
    
    func startInactivityMonitoring() {
        resetInactivityTimer()
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
        
        // Dim screen
        DispatchQueue.main.async {
            UIScreen.main.brightness = 0.2
        }
    }
    
    func exitScreensaver() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isScreensaverActive = false
        }
        
        // Restore screen brightness
        DispatchQueue.main.async {
            UIScreen.main.brightness = 1.0
        }
        
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
