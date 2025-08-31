import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @StateObject private var kioskManager = KioskManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var faceDetectionManager = FaceDetectionManager()
    
    var body: some View {
        ZStack {
            if kioskManager.isScreensaverActive {
                ScreensaverView()
                    .environmentObject(kioskManager)
                    .environmentObject(faceDetectionManager)
            } else {
                KioskWebView()
                    .environmentObject(kioskManager)
            }
        }
        .onAppear {
            setupApp()
        }
        .onReceive(faceDetectionManager.$faceDetected) { faceDetected in
            if faceDetected && kioskManager.isScreensaverActive {
                kioskManager.exitScreensaver()
            }
        }
        .statusBarHidden(true)
    }
    
    private func setupApp() {
        // Prevent device from sleeping
        UIApplication.shared.isIdleTimerDisabled = true
        
        UIScreen.main.brightness = 1.0

        // Setup audio session for continuous recording
        audioManager.setupAudioSession()
        audioManager.startRecording()
        
        // Start inactivity monitoring
        kioskManager.startInactivityMonitoring()
    }
}
