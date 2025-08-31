import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var homeAssistantConnected = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var homeAssistantClient: HomeAssistantClient?
    
    override init() {
        super.init()
        homeAssistantClient = HomeAssistantClient()
    }
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord,
                                       mode: .default,
                                       options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    func startRecording() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let audioEngine = audioEngine, let inputNode = inputNode else {
            return
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopRecording() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert audio buffer to Data and send to Home Assistant
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let audioData = Data(bytes: channelData, count: Int(buffer.frameLength) * MemoryLayout<Float>.size)
        homeAssistantClient?.sendAudioData(audioData)
    }
    
    func playAudioResponse(_ audioData: Data) {
        // Play audio response from Home Assistant
        // Implementation would convert Data back to audio and play it
        print("Playing audio response from Home Assistant")
    }
}
