import SwiftUI

struct ScreensaverView: View {
    @EnvironmentObject var kioskManager: KioskManager
    @EnvironmentObject var faceDetectionManager: FaceDetectionManager
    @EnvironmentObject var settings: SettingsManager
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text(currentTime, style: .time)
                    .font(.system(size: 80, weight: .thin, design: .default))
                    .foregroundColor(.white)
                
                Text(currentTime, style: .date)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.gray)
                
                if faceDetectionManager.isDetecting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Face detection active...")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                }
            }
        }
        .onReceive(timer) { input in
            currentTime = input
        }
        .onTapGesture {
            kioskManager.handleUserActivity()
        }
        .onAppear {
            faceDetectionManager.startDetection()
        }
        .onDisappear {
            faceDetectionManager.stopDetection()
        }
    }
}
