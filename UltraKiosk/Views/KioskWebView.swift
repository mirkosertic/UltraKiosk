import SwiftUI
import WebKit

struct KioskWebView: UIViewRepresentable {
    @EnvironmentObject var kioskManager: KioskManager
    @EnvironmentObject var settings: SettingsManager
    @StateObject private var webViewHandler = WebViewHandler()
    @State private var lastLoadedURL: String = ""
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Add message handlers for JavaScript communication
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "openSettings")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Store reference for JavaScript calls
        context.coordinator.webView = webView
        webViewHandler.webView = webView
        
        // Add gesture recognizer for user activity
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        webView.addGestureRecognizer(tapGesture)
        
        // Load demo HTML content
        loadContent(in: webView)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only reload if the URL has actually changed
        let currentURL = settings.kioskURL.isEmpty ? "demo" : settings.kioskURL
        if currentURL != lastLoadedURL {
            lastLoadedURL = currentURL
            loadContent(in: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, webViewHandler: webViewHandler)
    }
    
    private func loadContent(in webView: WKWebView) {
        if !settings.kioskURL.isEmpty, let url = URL(string: settings.kioskURL) {
            // Load custom kiosk URL
            webView.load(URLRequest(url: url))
            lastLoadedURL = settings.kioskURL
        } else {
            // Load demo content
            loadDemoContent(in: webView)
            lastLoadedURL = "demo"
        }
    }
    
    private func loadDemoContent(in webView: WKWebView) {
        let htmlContent = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <meta name="apple-mobile-web-app-capable" content="yes">
            <meta name="apple-mobile-web-app-status-bar-style" content="black-fullscreen">
            <title>UltraKiosk</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    height: 100vh;
                    overflow: hidden;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    position: relative;
                }

                /* Animated background elements */
                .bg-decoration {
                    position: absolute;
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    z-index: 1;
                }

                .bg-decoration::before {
                    content: '';
                    position: absolute;
                    top: -50%;
                    left: -50%;
                    width: 200%;
                    height: 200%;
                    background: radial-gradient(circle at 30% 70%, rgba(255,255,255,0.1) 0%, transparent 50%),
                                radial-gradient(circle at 80% 20%, rgba(255,255,255,0.05) 0%, transparent 50%);
                    animation: float 20s ease-in-out infinite;
                }

                @keyframes float {
                    0%, 100% { transform: translate(0, 0) rotate(0deg); }
                    25% { transform: translate(-20px, -20px) rotate(1deg); }
                    50% { transform: translate(20px, -10px) rotate(-1deg); }
                    75% { transform: translate(-10px, 20px) rotate(0.5deg); }
                }

                .container {
                    position: relative;
                    z-index: 2;
                    text-align: center;
                    max-width: 90%;
                    width: 100%;
                }

                /* Main title */
                .app-title {
                    font-size: clamp(3rem, 8vw, 6rem);
                    font-weight: 800;
                    background: linear-gradient(45deg, #ffffff, #f0f0f0, #ffffff);
                    background-size: 200% 200%;
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                    background-clip: text;
                    text-shadow: 0 4px 20px rgba(0,0,0,0.3);
                    margin-bottom: 2rem;
                    letter-spacing: -0.02em;
                    animation: shimmer 3s ease-in-out infinite;
                }

                @keyframes shimmer {
                    0%, 100% { background-position: 0% 50%; }
                    50% { background-position: 100% 50%; }
                }

                /* Configuration text */
                .config-text {
                    color: rgba(255,255,255,0.9);
                    font-size: clamp(1rem, 2.5vw, 1.25rem);
                    font-weight: 400;
                    line-height: 1.6;
                    max-width: 600px;
                    margin: 3rem auto 0;
                    text-shadow: 0 2px 10px rgba(0,0,0,0.2);
                    background: rgba(255,255,255,0.1);
                    backdrop-filter: blur(10px);
                    border-radius: 16px;
                    padding: 2rem;
                    border: 1px solid rgba(255,255,255,0.2);
                }

                .config-highlight {
                    color: #fbbf24;
                    font-weight: 600;
                }

                /* Responsive adjustments for iPad */
                @media screen and (max-width: 1024px) and (orientation: landscape) {
                    .container {
                        flex-direction: row;
                        align-items: center;
                        justify-content: space-between;
                        max-width: 95%;
                    }
                    
                    .app-title {
                        margin-bottom: 1rem;
                    }
                    
                    .config-text {
                        margin-top: 1rem;
                    }
                        font-size: 1rem;
                        padding: 1.5rem;
                    }
                }

                @media screen and (max-width: 768px) and (orientation: portrait) {
                    .config-text {
                        padding: 1.5rem;
                        margin-top: 2rem;
                    }
                }

                /* Subtle pulse animation for the entire interface */
                .container {
                    animation: breathe 8s ease-in-out infinite;
                }

                @keyframes breathe {
                    0%, 100% { transform: scale(1); }
                    50% { transform: scale(1.01); }
                }
            </style>
        </head>
        <body>
            <div class="bg-decoration"></div>
            
            <div class="container">
                <h1 class="app-title">UltraKiosk</h1>
                                
                <div class="config-text">
                    Welcome to UltraKiosk<br>
                    <span class="config-highlight">3 x Tap Settings</span> in the top corner to configure your kiosk experience.
                </div>
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    // WebView Handler for JavaScript communication
    class WebViewHandler: ObservableObject {
        weak var webView: WKWebView?
        
        func executeJavaScript(_ script: String) {
            webView?.evaluateJavaScript(script) { result, error in
                if let error = error {
                    AppLogger.webView.error("JavaScript execution failed: \(String(describing: error))")
                }
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: KioskWebView
        var webViewHandler: WebViewHandler
        weak var webView: WKWebView?
        
        init(_ parent: KioskWebView, webViewHandler: WebViewHandler) {
            self.parent = parent
            self.webViewHandler = webViewHandler
        }
        
        @objc func handleTap() {
            parent.kioskManager.handleUserActivity()
        }
        
        // Handle messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }
            
            switch message.name {
            case "openSettings":
                handleOpenSettings(action: action, data: body)
                
            default:
                AppLogger.webView.warning("Unhandled JavaScript message: \(message.name)")
            }
        }
        
        private func handleOpenSettings(action: String, data: [String: Any]) {
            switch action {
            case "open_settings":
                openSettings()
                
            default:
                break
            }
        }
        
        private func openSettings() {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
        
        private func formatUptime() -> String {
            let uptime = ProcessInfo.processInfo.systemUptime
            let hours = Int(uptime) / 3600
            let minutes = (Int(uptime) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}
