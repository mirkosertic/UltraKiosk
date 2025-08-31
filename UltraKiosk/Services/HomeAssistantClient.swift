import Foundation
import Network
import Combine

class HomeAssistantClient: ObservableObject {
    @Published var isConnected = false
    
    private let baseURL = "ws://homeassistant.local:8123" // Replace with your Home Assistant URL
    private let accessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwYTJmOTU1ZDYwNjY0YmI1YTc2NGU4ZDAyNTMwZTA1ZSIsImlhdCI6MTcxOTE0MTcxNiwiZXhwIjoyMDM0NTAxNzE2fQ.u2rLYy7Mc4VIQ9-x_25Ra2IRejvkXBsRX8lxvjBzPIM" // Replace with your token
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    init() {
        setupWebSocket()
    }
    
    private func setupWebSocket() {
        guard let url = URL(string: "\(baseURL)/api/websocket") else { return }
        
        session = URLSession(configuration: .default)
        webSocketTask = session?.webSocketTask(with: url)
        
        connectWebSocket()
    }
    
    private func connectWebSocket() {
        webSocketTask?.resume()
        
        // Listen for messages
        receiveMessage()
        
        // Send authentication
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
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func startNewPipeline() {
        // We are authenticated, so we start a new pipeline
        let startPipelineMessage : [String: Any] = [
            "id": 10,
            "type": "assist_pipeline/run",
            "start_stage": "wake_word",
            "end_stage": "tts",
            "input":[
                "sample_rate": 16000,
                "device_id": "Unknown",
                "timeout": 3
            ]
        ]
        
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
                
                if json?["type"] as? String == "auth_ok" {
                    print("Authentication successful!")
                    
                    // Starting new pipeline
                    DispatchQueue.main.async {
                        self.isConnected = true
                    }
                    
                    startNewPipeline()
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
        // Send audio data to Home Assistant Voice Pipeline
        let message = URLSessionWebSocketTask.Message.data(audioData)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Failed to send audio data: \(error)")
            }
        }
    }
}

extension Notification.Name {
    static let homeAssistantAudioReceived = Notification.Name("HomeAssistantAudioReceived")
}
