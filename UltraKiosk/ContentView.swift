import AVFoundation
import SwiftUI
import Vision

struct ContentView: View {
    @StateObject private var kioskManager = KioskManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var faceDetectionManager = FaceDetectionManager()
    @StateObject private var mqttManager = MQTTManager()
    @StateObject private var settings = SettingsManager.shared

    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Keep WebView alive and just control visibility
            KioskWebView()
                .environmentObject(kioskManager)
                .environmentObject(settings)
                .opacity(kioskManager.isScreensaverActive ? 0 : 1)
                .animation(.easeInOut(duration: 0.5), value: kioskManager.isScreensaverActive)
                .allowsHitTesting(!kioskManager.isScreensaverActive)

            // Screensaver overlay
            if kioskManager.isScreensaverActive {
                ScreensaverView()
                    .environmentObject(kioskManager)
                    .environmentObject(faceDetectionManager)
                    .environmentObject(settings)
                    .transition(.opacity)
            }

            // Settings Access (Hidden gesture area)
            VStack {
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.gray)
                        .cornerRadius(25)
                        .opacity(0.1)
                        .frame(width: 50, height: 50)
                        .onTapGesture(count: 3) {
                            showingSettings = true
                        }
                }
                Spacer()
            }
        }
        .onAppear {
            setupApp()
            setupNotifications()
        }
        .onReceive(faceDetectionManager.$faceDetected) { faceDetected in
            if faceDetected && kioskManager.isScreensaverActive {
                kioskManager.exitScreensaver()
            }
        }
        .onReceive(settings.$screensaverTimeout) { newTimeout in
            kioskManager.updateTimeout(newTimeout)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .statusBarHidden(true)
    }

    private func setupApp() {
        // Prevent device from sleeping
        UIApplication.shared.isIdleTimerDisabled = true

        UIScreen.main.brightness = 1.0

        // Setup audio session for continuous recording
        audioManager.setupAudioSession()

        // Start recording only if voice activation is enabled
        if settings.enableVoiceActivation {
            audioManager.startRecording()
        }

        // Start inactivity monitoring with current timeout
        kioskManager.startInactivityMonitoring()

        // Connect to MQTT if enabled
        if settings.enableMQTT {
            mqttManager.connect()
        }
    }

    private func setupNotifications() {
        // Settings changed notification
        NotificationCenter.default.addObserver(
            forName: .settingsChanged,
            object: nil,
            queue: .main
        ) { _ in
            handleSettingsChanged()
        }

        // Screensaver notification
        NotificationCenter.default.addObserver(
            forName: .mqttScreensaverActivated,
            object: nil,
            queue: .main
        ) { _ in
            handleScreensaverActivated()
        }
    }

    private func handleScreensaverActivated() {
        AppLogger.app.info("Activating screensaver")

        kioskManager.activateScreensaver()
    }

    private func handleSettingsChanged() {
        AppLogger.app.info("Settings changed – updating components")

        // Update audio recording based on voice activation setting
        if settings.enableVoiceActivation && !audioManager.isRecording {
            audioManager.startRecording()
        } else if !settings.enableVoiceActivation && audioManager.isRecording {
            audioManager.stopRecording()
        }

        // Update timeout
        kioskManager.updateTimeout(settings.screensaverTimeout)

        // Handle MQTT connection
        if settings.enableMQTT && !mqttManager.isConnected {
            mqttManager.connect()
        } else if !settings.enableMQTT && mqttManager.isConnected {
            mqttManager.disconnect()
        }
    }

}
