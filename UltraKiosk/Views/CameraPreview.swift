import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let faceDetectionManager: FaceDetectionManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        if let previewLayer = faceDetectionManager.getPreviewLayer() {
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
