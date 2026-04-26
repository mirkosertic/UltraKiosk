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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Reload settings to discard changes
                        settings.objectWillChange.send()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAndClose()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Validation error", isPresented: $showingValidationAlert) {
                Button("OK") { }
            } message: {
                Text(validationIssues.joined(separator: "\n"))
            }
            .alert("Reset settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("Do you want to reset all settings to the default values?")
            }
        }
    }
    
    private var mqttSection: some View {
        Section("MQTT Integration") {
            Toggle("Enable MQTT", isOn: $settings.enableMQTT)
            
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
                
                Toggle("Use TLS/SSL", isOn: $settings.mqttUseTLS)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username (optional)")
                    TextField("MQTT Username", text: $settings.mqttUsername)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password (optional)")
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
                    Text("Device Info (automatically generated)")
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
                    Text("Battery Update Interval: \(settings.batteryUpdateIntervalFormatted)")
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
                        Text("Test MQTT connection")
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
            
            Toggle("Use HTTPS", isOn: $settings.useHTTPS)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Access Token")
                SecureField("Long-lived Access Token", text: $settings.accessToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("Create a Long-lived Access Token in Home Assistant under Profile → Security")
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
                    Text("Test connection")
                }
            }
            .disabled(isTestingConnection)
            
            if !testConnectionResult.isEmpty {
                Text(testConnectionResult)
                    .font(.caption)
                    .foregroundColor(testConnectionResult.contains("Success") ? .green : .red)
            }
        }
    }
    
    private var screensaverSection: some View {
        Section("Screensaver") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Inactivity timeout: \(settings.screensaverTimeoutFormatted)")
                Slider(value: $settings.screensaverTimeout, in: 10...1800, step: 10) {
                    Text("Timeout")
                } minimumValueLabel: {
                    Text("10s")
                } maximumValueLabel: {
                    Text("30m")
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Screen brightness (dimmed): \(Int(settings.screenBrightnessDimmed * 100))%")
                Slider(value: $settings.screenBrightnessDimmed, in: 0.05...0.8, step: 0.05)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Screen brightness (normal): \(Int(settings.screenBrightnessNormal * 100))%")
                Slider(value: $settings.screenBrightnessNormal, in: 0.3...1.0, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "Face detection interval: %.1fs", settings.faceDetectionInterval))
                Slider(value: $settings.faceDetectionInterval, in: 0.1...5.0, step: 0.1) {
                    Text("Interval")
                } minimumValueLabel: {
                    Text("0.1s")
                } maximumValueLabel: {
                    Text("5s")
                }
            }
        }
    }
    
    private var voiceSection: some View {
        Section("Voice control") {
            Toggle("Enable voice activation", isOn: $settings.enableVoiceActivation)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Sample rate: \(settings.voiceSampleRate) Hz")
                let supportedSampleRates: [Int] = [8000, 12000, 16000, 22050, 32000, 44100]
                Picker("Sample rate", selection: $settings.voiceSampleRate) {
                    ForEach(supportedSampleRates, id: \.self) { rate in
                        Text("\(rate / 1000) kHz").tag(rate)
                    }
                }
                .pickerStyle(.menu)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Timeout: \(settings.voiceTimeout)s")
                Slider(value: Binding(
                    get: { Double(settings.voiceTimeout) },
                    set: { settings.voiceTimeout = Int($0) }
                ), in: 1...60, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Porcupine Access Token")
                SecureField("Long-lived Access Token", text: $settings.porcupineAccessToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("Create a Long-lived Access Token the Picovoice web console")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var kioskSection: some View {
        Section("Kiosk mode") {
            NavigationLink("Manage URLs (\(settings.slideshowURLs.count))") {
                URLListEditor(
                    committedURLs: $settings.slideshowURLs,
                    committedInterval: $settings.slideshowInterval
                )
            }
            Text(settings.slideshowURLs.isEmpty
                 ? "No URLs configured — demo page is shown"
                 : "\(settings.effectiveURLs.count) URL(s) · \(Int(settings.slideshowInterval)) s interval")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionsSection: some View {
        Section("Actions") {
            Button("Reset settings") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
            
            Button("Export settings") {
                exportSettings()
            }
        }
    }
    
    // MARK: - Actions
    private func saveAndClose() {
        validationIssues = settings.validateSettings()
        
        if validationIssues.isEmpty {
            settings.saveSettings() // Save settings explicitly
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
            testConnectionResult = "❌ Invalid port"
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
                connectionResult = "✅ MQTT connection successful"
                testClient.disconnect()
            } else {
                connectionResult = "❌ MQTT connection refused: \(ack)"
            }
        }
        
        if !testClient.connect() {
            testConnectionResult = "❌ MQTT Client could not be started"
            isTestingConnection = false
            return
        }
        
        // Wait for connection result
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.isTestingConnection = false
            self.testConnectionResult = connectionResult ?? "❌ Timeout during MQTT connection"
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
                    testConnectionResult = "Error: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        testConnectionResult = "✅ Connection successful"
                    } else {
                        testConnectionResult = "❌ HTTP \(httpResponse.statusCode)"
                    }
                } else {
                    testConnectionResult = "❌ Unknown error"
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

// MARK: - URL List Editor

private let maxURLCount = 5

/// Allows the user to add, remove, reorder, and edit slideshow URLs,
/// and to configure the transition interval when more than one URL is set.
/// Operates on a local copy; changes are committed only on Save.
struct URLListEditor: View {

    /// The committed values from SettingsManager — only written on Save.
    @Binding var committedURLs: [String]
    @Binding var committedInterval: Double

    /// Local working copies — discarded on Cancel.
    @State private var urls: [String]
    @State private var interval: Double

    @Environment(\.dismiss) private var dismiss

    init(committedURLs: Binding<[String]>, committedInterval: Binding<Double>) {
        _committedURLs = committedURLs
        _committedInterval = committedInterval
        _urls = State(initialValue: committedURLs.wrappedValue)
        _interval = State(initialValue: committedInterval.wrappedValue)
    }

    var body: some View {
        List {
            Section("URLs") {
                ForEach(Array(urls.enumerated()), id: \.offset) { i, _ in
                    TextField("https://your-dashboard.local", text: $urls[i])
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .onMove { from, to in urls.move(fromOffsets: from, toOffset: to) }
                .onDelete { idx in urls.remove(atOffsets: idx) }

                if urls.count < maxURLCount {
                    Button {
                        urls.append("")
                    } label: {
                        Label("Add URL", systemImage: "plus.circle")
                    }
                } else {
                    Text("Maximum of \(maxURLCount) URLs reached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if urls.count > 1 {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transition interval: \(Int(interval)) s")
                        Slider(value: $interval, in: 5...300, step: 5) {
                            Text("Interval")
                        } minimumValueLabel: {
                            Text("5 s")
                        } maximumValueLabel: {
                            Text("5 min")
                        }
                    }
                } header: {
                    Text("Slideshow")
                } footer: {
                    Text("Time each slide is shown before cross-fading to the next.")
                }
            }
        }
        .navigationTitle("Slideshow URLs")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    committedURLs = urls
                    committedInterval = interval
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let settingsChanged = Notification.Name("SettingsChanged")
    static let openSettings = Notification.Name("OpenSettings")
    /// Posted after settings are saved and the WKWebView cache has been cleared.
    /// Every KioskWebView reloads its content when it receives this notification.
    static let reloadAllWebViews = Notification.Name("UltraKiosk.reloadAllWebViews")
}
