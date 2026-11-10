import AppKit
import QuartzCore
import Combine
import SwiftUI

/// Moves the prompter text. "Follow my words" eases toward the line being read and overrides everything else;
/// otherwise pause-on-hover holds the text, and the play button or "voice level" (sound on the mic) scroll it at the
/// set speed.
final class ScrollController: ObservableObject {
    /// Vertical offset of the text, in points. The prompter re-renders when it changes and scrolls its text view there.
    @Published private(set) var offsetValue: CGFloat = 0

    var scrollOffset: CGFloat {
        get { offsetValue }
        set {
            let clamped = min(max(0, newValue), maxOffset)
            if clamped != offsetValue { offsetValue = clamped }
        }
    }

    /// The furthest the text can scroll, kept up to date by the text view.
    var maxOffset: CGFloat = .greatestFiniteMagnitude

    /// Where the text view wants the scroll to settle while following spoken words.
    var followTarget: CGFloat?

    var isPaused: () -> Bool = { false }
    var isAutoScrolling: () -> Bool = { false }
    var isFollowingWords: () -> Bool = { false }
    var isSpeaking: () -> Bool = { false }

    /// Whether anything can move the text right now (playing, or listening). The frame timer only runs while this is
    /// true, so an idle prompter costs no CPU and lets the Mac sleep the app (App Nap).
    var isActive = false {
        didSet {
            guard isActive != oldValue else { return }
            isActive ? startTimer() : stopTimer()
        }
    }

    private var timer: Timer?
    private var lastTick: CFTimeInterval = 0

    /// Step size (pt) for keyboard arrow scroll.
    static let keyboardScrollStep: CGFloat = 24

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        lastTick = CACurrentMediaTime()
        // 120 Hz so ProMotion displays get a frame each refresh; steps use the real elapsed time, so speed is the same
        // at any rate and after a stall.
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 1.0 / 480
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(min(0.1, max(0, now - lastTick)))
        lastTick = now
        // Following words comes first: the voice leads, so the play button and hover pause do not apply.
        if isFollowingWords() {
            guard let target = followTarget else { return }
            let distance = target - scrollOffset
            guard abs(distance) > 0.5 else { return }
            // Ease: cover about a tenth of the gap every 1/60 s, so a new line glides in over a third of a second.
            scrollOffset += distance * (1 - pow(0.9, dt * 60))
            return
        }
        guard !isPaused() else { return }
        if isAutoScrolling() || isSpeaking() {
            let speed = CGFloat(UserDefaults.standard.object(forKey: NotchyKeys.scrollSpeed) as? Double ?? 40)
            scrollOffset += speed * dt
        }
    }

    func resetScroll() {
        followTarget = nil
        scrollOffset = 0
    }
}
