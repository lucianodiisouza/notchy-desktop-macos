import SwiftUI

final class ScrollController: ObservableObject {
    @Published var scrollOffset: CGFloat = 0
    @Published var contentHeight: CGFloat = 0

    var isSpeakingBinding: Binding<Bool>? {
        didSet { setupTimer() }
    }
    /// When set, scroll runs at scrollSpeed (pt/s) independent of voice.
    var autoScrollPlayingBinding: Binding<Bool>? {
        didSet { setupTimer() }
    }
    /// When set and wrappedValue is true, scroll is paused (e.g. pause on hover).
    var pauseWhenHoveringBinding: Binding<Bool>? {
        didSet { setupTimer() }
    }

    @AppStorage(NotchyKeys.scrollSpeed) private var scrollSpeed: Double = 40

    private var timer: Timer?
    private let timerInterval: TimeInterval = 0.05

    private func setupTimer() {
        timer?.invalidate()
        timer = nil
        guard isSpeakingBinding != nil || autoScrollPlayingBinding != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        if pauseWhenHoveringBinding?.wrappedValue == true { return }
        let voiceScroll = isSpeakingBinding?.wrappedValue == true
        let autoScroll = autoScrollPlayingBinding?.wrappedValue == true
        guard voiceScroll || autoScroll else { return }
        let speed = scrollSpeed * CGFloat(timerInterval)
        scrollOffset += speed
    }

    /// Step size (pt) for keyboard arrow scroll. Used by ContentView.
    static let keyboardScrollStep: CGFloat = 24

    func resetScroll() {
        scrollOffset = 0
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
}
