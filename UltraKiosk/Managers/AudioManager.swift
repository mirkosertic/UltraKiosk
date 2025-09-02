import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    
    @Published var isRecording = false
    @Published var homeAssistantConnected = false
    
    // Configure preferred recording format
    private var preferredSampleRate: Double = 16000
    private var preferredNumChannels: Int = 1 // 1 = mono, 2 = stereo
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var homeAssistantClient: HomeAssistantClient?
    private var player: AVPlayer?
    private var mixerNode: AVAudioMixerNode?
    
    override init() {
        super.init()
        homeAssistantClient = HomeAssistantClient()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleHomeAssistantFormatChanged(_:)),
                                               name: .homeAssistantFormatChanged,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleHomeAssistantPipelineFeedback(_:)),
                                               name: .homeAssistantPipelineFeedback,
                                               object: nil)
    }
    
    @objc private func handleHomeAssistantFormatChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let sampleRateInt = userInfo["sample_rate"] as? Int
        let channels = userInfo["channels"] as? Int
        let sampleRate = sampleRateInt != nil ? Double(sampleRateInt!) : nil
        reinitializeAudioSession(sampleRate: sampleRate, channels: channels)
    }
    
    @objc private func handleHomeAssistantPipelineFeedback(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        guard let urlString = userInfo["url"] as? String, let url = URL(string: urlString) else {
            return
        }
        playMP3(from: url)
    }
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord,
                                         mode: .default,
                                         options: [.defaultToSpeaker, .allowBluetooth])
            
            // Apply preferred format settings
            try audioSession.setPreferredSampleRate(preferredSampleRate)
            if audioSession.isInputAvailable {
                try? audioSession.setPreferredInputNumberOfChannels(preferredNumChannels)
            }
            
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
        
        // Desired recording format that downstream consumers expect
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: preferredSampleRate,
                                          channels: AVAudioChannelCount(preferredNumChannels),
                                          interleaved: false)
        
        // Build graph: input -> mixer -> mainMixer
        let mixer = AVAudioMixerNode()
        mixerNode = mixer
        audioEngine.attach(mixer)
        
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        audioEngine.connect(inputNode, to: mixer, format: hardwareFormat)
        audioEngine.connect(mixer, to: audioEngine.mainMixerNode, format: desiredFormat)
        
        // Install tap on mixer so we receive buffers in the desired format (engine converts)
        mixer.installTap(onBus: 0, bufferSize: 1024, format: desiredFormat) { [weak self] buffer, _ in
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
    
    // Reinitialize audio session and restart recording (if active) when format changes
    func reinitializeAudioSession(sampleRate: Double? = nil, channels: Int? = nil) {
        let wasRecording = isRecording
        if wasRecording {
            stopRecording()
        }
        
        if let newRate = sampleRate {
            preferredSampleRate = newRate
        }
        if let newChannels = channels {
            preferredNumChannels = newChannels
        }
        
        // Deactivate current session before reconfiguring
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal, continue to reconfigure
        }
        
        setupAudioSession()
        
        if wasRecording {
            startRecording()
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
    
    // Plays an MP3 from a remote or local URL using AVPlayer
    func playMP3(from url: URL) {
        do {
            // Keep current category (.playAndRecord) but ensure session is active and speaker is used
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("Audio session activation/override failed: \(error)")
        }
        
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
    }
}
