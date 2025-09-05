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
    private var playbackObserver: NSObjectProtocol?
    
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
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleHomeAssistantSpeechToText(_:)),
                                               name: .homeAssistantSpeechToText,
                                               object: nil)

    }
    
    // Plays a short feedback sound. Preferred: bundled asset (e.g. "bing.caf").
    func playFeedbackSound(assetName: String = "bing", assetExtension: String = "caf") {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            AppLogger.audio.error("Audio session activation/override failed for feedback: \(String(describing: error))")
        }
        
        if let url = Bundle.main.url(forResource: assetName, withExtension: assetExtension) {
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            
            // Add observer for playback completion
            playbackObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.handlePlaybackCompleted()
            }

            player?.play()
            return
        }
    }

    @objc private func handleHomeAssistantSpeechToText(_ notification: Notification) {
        playFeedbackSound(assetName: "Speech_On", assetExtension: "wav")
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
    
    private func handlePlaybackCompleted() {
        // Remove the observer
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackObserver = nil
        }
        
        player = nil
        
        // Restore audio session for recording
        do {
            let session = AVAudioSession.sharedInstance()
            // Remove the speaker override to restore normal routing
            try session.overrideOutputAudioPort(.none)
            // Reconfigure the session for recording
            setupAudioSession()
        } catch {
            AppLogger.audio.error("Failed to restore audio session after playback: \(String(describing: error))")
        }
        
        // Resume recording if it was active before playback
        if isRecording {
            stopRecording()
            
            // Give a small delay to ensure cleanup is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startRecording()
            }
        }
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
            AppLogger.audio.error("Audio session setup failed: \(String(describing: error))")
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

        // Prevent microphone monitoring through speakers while still allowing taps to receive data
        audioEngine.mainMixerNode.outputVolume = 0
        
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
            AppLogger.audio.error("Failed to start audio engine: \(String(describing: error))")
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

        mixerNode?.removeTap(onBus: 0)
        mixerNode = nil
        inputNode = nil
        audioEngine = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert Float32 [-1, 1] to signed 16-bit PCM (little-endian) and send
        guard let floatChannelPointer = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        var pcm16Samples = [Int16](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let sample = floatChannelPointer[i]
            // Clamp to [-1, 1]
            let clamped = max(-1.0, min(1.0, sample))
            // Scale and convert to Int16 (use 32767 for positive range, 32768 for negative)
            let scaled: Float = clamped < 0 ? (clamped * 32768.0) : (clamped * 32767.0)
            let intSample = Int16(scaled)
            pcm16Samples[i] = Int16(littleEndian: intSample)
        }
        
        let audioData = pcm16Samples.withUnsafeBufferPointer { bufferPtr in
            Data(buffer: bufferPtr)
        }
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
            AppLogger.audio.error("Audio session activation/override failed: \(String(describing: error))")
        }
        
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        
        // Add observer for playback completion
        playbackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackCompleted()
        }

        player?.play()
    }
}
