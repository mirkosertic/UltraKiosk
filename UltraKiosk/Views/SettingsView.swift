import SwiftUI
import CocoaMQTT

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingValidationAlert = false
    @State private var validationIssues: [String] = []
    @State private var showingResetAlert = false
    @State private var testConnectionResult = ""
    @State private var isTestingConnection = false
    
    var body: some View {
        NavigationView {
            Form {
                homeAssistantSection
                mqttSection
                screensaverSection
                voiceSection
                kioskSection
                actionsSection
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        saveAndClose()
                    }
                    //.fontWeight(.semibold)
                }
            }
            .alert("Validierungsfehler", isPresented: $showingValidationAlert) {
                Button("OK") { }
            } message: {
                Text(validationIssues.joined(separator: "\n"))
            }
            .alert("Einstellungen zurücksetzen", isPresented: $showingResetAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Zurücksetzen", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("Möchten Sie alle Einstellungen auf die Standardwerte zurücksetzen?")
            }
        }
    }
    
    private var mqttSection: some View {
        Section("MQTT Integration") {
            Toggle("MQTT aktivieren", isOn: $settings.enableMQTT)
            
            if settings.enableMQTT {
                HStack {
                    Text("Broker IP/Name")
                    Spacer()
                    TextField("192.168.1.100", text: $settings.mqttBrokerIP)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 150)
                }
                
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("1883", text: $settings.mqttPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 100)
                }
                
                Toggle("TLS/SSL verwenden", isOn: $settings.mqttUseTLS)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Benutzername (optional)")
                    TextField("MQTT Username", text: $settings.mqttUsername)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Passwort (optional)")
                    SecureField("MQTT Password", text: $settings.mqttPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Topic Prefix")
                    TextField("homeassistant", text: $settings.mqttTopicPrefix)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Info (automatisch generiert)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let mqttManager = getMQTTManager() {
                        let deviceInfo = mqttManager.getDeviceInfo()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Device ID: \(deviceInfo["device_id"] ?? "N/A")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Device Name: \(deviceInfo["device_name"] ?? "N/A")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Model: \(deviceInfo["model_identifier"] ?? "N/A")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Batterie Update Interval: \(settings.batteryUpdateIntervalFormatted)")
                    Slider(value: $settings.mqttBatteryUpdateInterval, in: 30...600, step: 30) {
                        Text("Interval")
                    } minimumValueLabel: {
                        Text("30s")
                    } maximumValueLabel: {
                        Text("10m")
                    }
                }
                
                Button(action: testMQTTConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text("MQTT Verbindung testen")
                    }
                }
                .disabled(isTestingConnection)
                
                if !testConnectionResult.isEmpty {
                    Text(testConnectionResult)
                        .font(.caption)
                        .foregroundColor(testConnectionResult.contains("Erfolgreich") ? .green : .red)
                }
            }
        }
    }
    
    private var homeAssistantSection: some View {
        Section("Home Assistant") {
            HStack {
                Text("IP/Name")
                Spacer()
                TextField("192.168.1.100", text: $settings.homeAssistantIP)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 150)
            }
            
            HStack {
                Text("Port")
                Spacer()
                TextField("8123", text: $settings.homeAssistantPort)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 100)
            }
            
            Toggle("HTTPS verwenden", isOn: $settings.useHTTPS)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Access Token")
                SecureField("Long-lived Access Token", text: $settings.accessToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("Erstellen Sie einen Long-lived Access Token in Home Assistant unter Profile → Security")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: testConnection) {
                HStack {
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "network")
                    }
                    Text("Verbindung testen")
                }
            }
            .disabled(isTestingConnection)
            
            if !testConnectionResult.isEmpty {
                Text(testConnectionResult)
                    .font(.caption)
                    .foregroundColor(testConnectionResult.contains("Erfolgreich") ? .green : .red)
            }
        }
    }
    
    private var screensaverSection: some View {
        Section("Screensaver") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Inaktivitäts-Timeout: \(settings.screensaverTimeoutFormatted)")
                Slider(value: $settings.screensaverTimeout, in: 10...1800, step: 10) {
                    Text("Timeout")
                } minimumValueLabel: {
                    Text("10s")
                } maximumValueLabel: {
                    Text("30m")
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Bildschirmhelligkeit (gedimmt): \(Int(settings.screenBrightnessDimmed * 100))%")
                Slider(value: $settings.screenBrightnessDimmed, in: 0.05...0.8, step: 0.05)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Bildschirmhelligkeit (normal): \(Int(settings.screenBrightnessNormal * 100))%")
                Slider(value: $settings.screenBrightnessNormal, in: 0.3...1.0, step: 0.05)
            }
        }
    }
    
    private var voiceSection: some View {
        Section("Sprachsteuerung") {
            Toggle("Voice Activation aktivieren", isOn: $settings.enableVoiceActivation)
        }
    }
    
    private var kioskSection: some View {
        Section("Kiosk-Modus") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kiosk-URL (optional)")
                TextField("https://your-dashboard.com", text: $settings.kioskURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                Text("Leer lassen für Demo-Seite")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var actionsSection: some View {
        Section("Aktionen") {
            Button("Einstellungen zurücksetzen") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
            
            Button("Einstellungen exportieren") {
                exportSettings()
            }
        }
    }
    
    // MARK: - Actions
    private func saveAndClose() {
        validationIssues = settings.validateSettings()
        
        if validationIssues.isEmpty {
            presentationMode.wrappedValue.dismiss()
        } else {
            showingValidationAlert = true
        }
    }
    
    private func getMQTTManager() -> MQTTManager? {
        // In a real implementation, this would be injected or accessed via environment
        // For now, create a temporary instance just to get device info
        return MQTTManager()
    }
    
    private func testMQTTConnection() {
        isTestingConnection = true
        testConnectionResult = ""
        
        // Simple MQTT connection test using CocoaMQTT
        guard let port = UInt16(settings.mqttPort) else {
            testConnectionResult = "❌ Ungültiger Port"
            isTestingConnection = false
            return
        }
        
        let testClient = CocoaMQTT(clientID: "test_client", host: settings.mqttBrokerIP, port: port)
        testClient.username = settings.mqttUsername.isEmpty ? nil : settings.mqttUsername
        testClient.password = settings.mqttPassword.isEmpty ? nil : settings.mqttPassword
        testClient.enableSSL = settings.mqttUseTLS
        testClient.keepAlive = 5
        testClient.cleanSession = true
        
        var connectionResult: String?
        
        testClient.didConnectAck = { _, ack in
            if ack == .accept {
                connectionResult = "✅ MQTT Verbindung erfolgreich"
                testClient.disconnect()
            } else {
                connectionResult = "❌ MQTT Verbindung abgelehnt: \(ack)"
            }
        }
        
        if !testClient.connect() {
            testConnectionResult = "❌ MQTT Client konnte nicht gestartet werden"
            isTestingConnection = false
            return
        }
        
        // Wait for connection result
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.isTestingConnection = false
            self.testConnectionResult = connectionResult ?? "❌ Timeout bei MQTT Verbindung"
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        testConnectionResult = ""
        
        let url = URL(string: "\(settings.homeAssistantBaseURL)/api/")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(settings.accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isTestingConnection = false
                
                if let error = error {
                    testConnectionResult = "Fehler: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        testConnectionResult = "✅ Verbindung erfolgreich"
                    } else {
                        testConnectionResult = "❌ HTTP \(httpResponse.statusCode)"
                    }
                } else {
                    testConnectionResult = "❌ Unbekannter Fehler"
                }
            }
        }.resume()
    }
    
    private func exportSettings() {
        let settings = settings.exportSettings()
        if let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            
            let activityViewController = UIActivityViewController(
                activityItems: [jsonString],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityViewController, animated: true)
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let settingsChanged = Notification.Name("SettingsChanged")
    static let openSettings = Notification.Name("OpenSettings")
}
