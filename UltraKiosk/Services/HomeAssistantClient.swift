import Foundation
import Network
import Combine

class HomeAssistantClient: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    
    private let settings = SettingsManager.shared
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var currentBinaryData: Int = -1
    private var processId: Int = 0
    private var conversationId : String = ""
    
    init() {
        setupWebSocket()
        
        // Listen for settings changes
        NotificationCenter.default.addObserver(
            forName: .settingsChanged,
            object: nil,
            queue: .main
        ) { _ in
            self.reconnectIfNeeded()
        }
    }
    
    private var baseURL: String {
        return settings.homeAssistantWebSocketURL
    }
    
    private var accessToken: String {
        return settings.accessToken
    }
    
    private func reconnectIfNeeded() {
        // Reconnect if settings changed and we have valid configuration
        if !settings.accessToken.isEmpty && !settings.homeAssistantIP.isEmpty {
            webSocketTask?.cancel()
            setupWebSocket()
        }
    }
    
    private func setupWebSocket() {
        guard !settings.accessToken.isEmpty,
              !settings.homeAssistantIP.isEmpty,
              let url = URL(string: "\(baseURL)/api/websocket") else { 
            updateConnectionStatus("Konfiguration unvollständig")
            return 
        }
        
        session = URLSession(configuration: .default)
        webSocketTask = session?.webSocketTask(with: url)
        
        connectWebSocket()
    }
    
    private func updateConnectionStatus(_ status: String) {
        DispatchQueue.main.async {
            self.connectionStatus = status
            self.isConnected = (status == "Connected")
        }
    }
    
    private func connectWebSocket() {
        updateConnectionStatus("Connecting...")
        webSocketTask?.resume()
        
        // Listen for messages
        receiveMessage()
        
        // Send authentication after connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.authenticateWithHomeAssistant()
        }
    }
    
    private func authenticateWithHomeAssistant() {
        let authMessage = [
            "type": "auth",
            "access_token": accessToken
        ]
        
        sendMessage(authMessage)
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else { return }
        
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    self?.handleAudioData(data)
                @unknown default:
                    break
                }
                self?.receiveMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.updateConnectionStatus("Connection Lost")
                
                // Attempt reconnection
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.connectWebSocket()
                }
            }
        }
    }
    
    private func startNewPipeline() {
        // We are authenticated, so we start a new pipeline
        processId += 1
        
        let startPipelineMessage : [String: Any] = [
            "id": processId,
            "type": "assist_pipeline/run",
            "start_stage": "wake_word",
            "end_stage": "tts",
            "input":[
                "sample_rate": 16000,
                "device_id": "Unknown",
                "timeout": 3
            ]
        ]
        
        currentBinaryData = -1
        
        print("Starting new voice pipeline")
        sendMessage(startPipelineMessage)
    }
    
    private func handleMessage(_ message: String) {
        // Handle text messages from Home Assistant
        print("Received message: \(message)")
        
        if let data = message.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("Got JSON data!")
                
                let id = json?["id"] as? Int ?? -1
                if (id != processId) {
                    print("Got event with id \(id), expected \(processId), ignoring.")
                    return
                }
                
                if json?["type"] as? String == "auth_ok" {
                    print("Authentication successful!")
                    
                    updateConnectionStatus("Connected")
                    
                    startNewPipeline()
                }
                
                if json?["type"] as? String == "auth_invalid" {
                    print("Authentication failed!")
                    
                    updateConnectionStatus("Auth Failed")
                }
                
                if json?["type"] as? String == "event" {
                    let eventData = json?["event"] as? [String: Any]
                    if eventData?["type"] as? String == "run-start" {
                        print("Pipeline started!")
                        let data = eventData?["data"] as? [String: Any]
                        conversationId = data?["conversation_id"] as? String ?? ""
                        print("Conversation ID: \(conversationId)")
                        let runnertData = data?["runner_data"] as? [String: Any]
                        currentBinaryData = runnertData?["stt_binary_handler_id"] as? Int ?? -1
                        print("Current binary data handler: \(currentBinaryData)")
                    }
                    if eventData?["type"] as? String == "wake_word-start" {
                        print("Wakeword detection started!")
                        let data = eventData?["data"] as? [String: Any]
                        let meta = (data?["metadata"] as? [String: Any])
                        let format = meta?["format"] as? String
                        let codec = meta?["codec"] as? String
                        let bitrate = meta?["bit_rate"] as? Int ?? -1
                        let samplerate = meta?["sample_rate"] as? Int ?? -1
                        let channels = meta?["channel"] as? Int ?? 1
                        print("Expected format and codec is \(format ?? "unknown"), \(codec ?? "unknown"), \(bitrate), \(samplerate)")
                        
                        if (bitrate != -1 && samplerate != -1) {
                            print("Reinitializing audio session with sample rate \(samplerate) and bitrate \(bitrate)")
                            NotificationCenter.default.post(
                                name: .homeAssistantFormatChanged,
                                object: nil,
                                userInfo: [
                                    "sample_rate": samplerate,
                                    "channels": channels
                                ]
                            )
                        }
                    }
                    if eventData?["type"] as? String == "stt-start" {
                        print("STT started!")
                        let data = eventData?["data"] as? [String: Any]
                        let meta = (data?["metadata"] as? [String: Any])
                        let format = meta?["format"] as? String
                        let codec = meta?["codec"] as? String
                        let bitrate = meta?["bit_rate"] as? Int ?? -1
                        let samplerate = meta?["sample_rate"] as? Int ?? -1
                        let channels = meta?["channel"] as? Int ?? 1
                        print("Expected format and codec is \(format ?? "unknown"), \(codec ?? "unknown"), \(bitrate), \(samplerate)")
                        
                        if (bitrate != -1 && samplerate != -1) {
                            print("Reinitializing audio session with sample rate \(samplerate) and bitrate \(bitrate)")
                            NotificationCenter.default.post(
                                name: .homeAssistantFormatChanged,
                                object: nil,
                                userInfo: [
                                    "sample_rate": samplerate,
                                    "channels": channels
                                ]
                            )
                        }
                    }
                    if eventData?["type"] as? String == "tts-end" {
                        print("TTS ended!")
                        let data = eventData?["data"] as? [String: Any]

                        let ttsoutput = (data?["tts_output"] as? [String: Any])
                        let url = ttsoutput?["url"] as? String ?? "unknown"
                        print("URL to play is : \(url)")
                        
                        NotificationCenter.default.post(
                            name: .homeAssistantPipelineFeedback,
                            object: nil,
                            userInfo: [
                                "url": SettingsManager.shared.homeAssistantBaseURL + url
                            ]
                        )
                    }
                    if eventData?["type"] as? String == "error" {
                        print("Got error")
                        let data = eventData?["data"] as? [String: Any]
                        let code = data?["code"] as? String
                        let message = data?["message"] as? String
                        print("Error code: \(code ?? "unknown"), Error message: \(message ?? "unknown")")
                    }
                    if eventData?["type"] as? String == "run-end" {
                        print("Pipeline ended")
                        startNewPipeline()
                    }
                    
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        
        // TODO: Parse the following HA responses:
        // Received message: {"id":10,"type":"result","success":true,"result":null}
        // Received message: {"id":10,"type":"event","event":{"type":"run-start","data":////{"pipeline":"01hkwkxrt1qb7n37tpj8r6n7m8","language":"de","conversation_id":"01K3YGBJP1ZJ8R0ENZCFY6S1V1","runner_data":{"stt_binary_handler_id":1,"timeout":300},"tts_output":{"token":"q99-f7z1ro3L_8PgjE8rUw.mp3","url":"/api/tts_proxy/q99-f7z1ro3L_8PgjE8rUw.mp3","mime_type":"audio/mpeg","stream_response":false}},"timestamp":"2025-08-30T22:07:52.005147+00:00"}}
        // Received message: {"id":10,"type":"event","event":{"type":"wake_word-start","data":{"entity_id":"wake_word.openwakeword","metadata":{"format":"wav","codec":"pcm","bit_rate":16,"sample_rate":16000,"channel":1},"timeout":3},"timestamp":"2025-08-30T22:07:52.005266+00:00"}}
        // Received message: {"id":10,"type":"event","event":{"type":"error","data":{"code":"wake-word-timeout","message":"Wake word was not detected"},"timestamp":"2025-08-30T22:11:07.741333+00:00"}}
        // Received message: {"id":10,"type":"event","event":{"type":"run-end","data":null,"timestamp":"2025-08-30T22:11:07.743620+00:00"}}
    }
    
    private func handleAudioData(_ data: Data) {
        // Handle audio response from Home Assistant Voice Pipeline
        NotificationCenter.default.post(name: .homeAssistantAudioReceived, object: data)
    }
    
    func sendAudioData(_ audioData: Data) {
        // Prefix currentBinaryData as a single byte, then append audio data
        guard currentBinaryData >= 0 else { return }
        var payload = Data()
        payload.reserveCapacity(1 + audioData.count)
        payload.append(UInt8(truncatingIfNeeded: currentBinaryData))
        payload.append(audioData)
        
        webSocketTask?.send(.data(payload)) { error in
            if let error = error {
                print("Failed to send audio data: \(error)")
            }
        }
    }
}

extension Notification.Name {
    static let homeAssistantAudioReceived = Notification.Name("HomeAssistantAudioReceived")
    static let homeAssistantFormatChanged = Notification.Name("HomeAssistantFormatChanged")
    static let homeAssistantPipelineFeedback = Notification.Name("HomeAssistantPipelineFeedback")
}
