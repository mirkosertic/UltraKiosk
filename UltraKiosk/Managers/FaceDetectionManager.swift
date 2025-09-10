import SwiftUI
import AVFoundation
import Vision
import Combine

class FaceDetectionManager: NSObject, ObservableObject {
    @Published var faceDetected = false
    @Published var isDetecting = false
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Frame rate limiting properties
    private var lastDetectionTime: CFTimeInterval = 0
    private var detectionInterval: CFTimeInterval = SettingsManager.shared.faceDetectionInterval
    private var pendingPixelBuffer: CVPixelBuffer?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func updateDetectionInterval(_ newInterval: CFTimeInterval) {
        sessionQueue.async { [weak self] in
            self?.detectionInterval = newInterval
            self?.lastDetectionTime = 0
        }
    }
    
    func reinitialize(withInterval newInterval: CFTimeInterval) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let wasDetecting = self.isDetecting
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.previewLayer = nil
            self.detectionInterval = newInterval
            self.lastDetectionTime = 0
            self.configureCaptureSession()
            if wasDetecting {
                self.captureSession?.startRunning()
                DispatchQueue.main.async {
                    self.isDetecting = true
                }
            }
        }
    }
    
    func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .low
        
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera),
              let captureSession = captureSession else {
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
    }
    
    func startDetection() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isDetecting = true
            }
        }
    }
    
    func stopDetection() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.isDetecting = false
                self?.faceDetected = false
            }
        }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
    
    private func shouldProcessFrame() -> Bool {
        let currentTime = CACurrentMediaTime()
        if currentTime - lastDetectionTime >= detectionInterval {
            lastDetectionTime = currentTime
            return true
        }
        return false
    }
    
    private func processFaceDetection(pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation] else { return }
            
            DispatchQueue.main.async {
                let hasFaces = !results.isEmpty
                if hasFaces != self?.faceDetected {
                    self?.faceDetected = hasFaces
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

extension FaceDetectionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Store the latest frame for potential processing
        pendingPixelBuffer = pixelBuffer
        
        // Only process face detection if enough time has passed
        if shouldProcessFrame() {
            processFaceDetection(pixelBuffer: pixelBuffer)
        }
    }
}
