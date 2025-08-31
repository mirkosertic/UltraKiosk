import SwiftUI
import WebKit

struct KioskWebView: UIViewRepresentable {
    @EnvironmentObject var kioskManager: KioskManager
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Add gesture recognizer for user activity
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        webView.addGestureRecognizer(tapGesture)
        
        // Load demo HTML content
        loadDemoContent(in: webView)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func loadDemoContent(in webView: WKWebView) {
        webView.load(URLRequest(url: URL(string: "http://homeassistant.local:8123/anzeige-flur/0?kiosk=true")!))
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: KioskWebView
        
        init(_ parent: KioskWebView) {
            self.parent = parent
        }
        
        @objc func handleTap() {
            parent.kioskManager.handleUserActivity()
        }
    }
}
