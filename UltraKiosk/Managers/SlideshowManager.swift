import Foundation
import Combine

/// Manages the slideshow timer and tracks the currently visible slide index.
/// Automatically pauses when the screensaver is active and resumes from the
/// same index when the screensaver is dismissed.
final class SlideshowManager: ObservableObject {

    @Published var currentIndex: Int = 0

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private weak var settings: SettingsManager?
    private weak var kioskManager: KioskManager?

    /// Wires up Combine observers and prepares the manager for use.
    /// Must be called once from ContentView.onAppear before start().
    func configure(settings: SettingsManager, kioskManager: KioskManager) {
        self.settings = settings
        self.kioskManager = kioskManager

        // Pause timer while screensaver is active; resume when dismissed
        kioskManager.$isScreensaverActive
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                isActive ? self?.pauseTimer() : self?.startTimer()
            }
            .store(in: &cancellables)

        // Restart when the URL list changes (e.g. user edits settings at runtime)
        settings.$slideshowURLs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.restart() }
            .store(in: &cancellables)

        // Restart when the interval changes
        settings.$slideshowInterval
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.restart() }
            .store(in: &cancellables)
    }

    /// Starts the slideshow. Call after configure().
    func start() { restart() }

    // MARK: - Private

    private func startTimer() {
        guard let s = settings,
              s.effectiveURLs.count > 1,
              kioskManager?.isScreensaverActive == false else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: s.slideshowInterval, repeats: true) { [weak self] _ in
            self?.advance()
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        // currentIndex is intentionally NOT reset — slideshow resumes from the same slide
    }

    private func restart() {
        pauseTimer()
        let count = settings?.effectiveURLs.count ?? 0
        // Clamp index in case the URL list shrank — only write if it actually changes
        // to avoid spurious @Published emissions that break Combine test subscribers.
        if count > 0 {
            let clamped = min(currentIndex, count - 1)
            if clamped != currentIndex { currentIndex = clamped }
        }
        startTimer()
    }

    private func advance() {
        guard let count = settings?.effectiveURLs.count, count > 1 else { return }
        currentIndex = (currentIndex + 1) % count
    }
}
