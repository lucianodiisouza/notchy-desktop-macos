import AppKit
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

    private var timer: Timer?
    private let frameInterval: TimeInterval = 1.0 / 60

    /// Step size (pt) for keyboard arrow scroll.
    static let keyboardScrollStep: CGFloat = 24

    init() {
        let timer = Timer(timeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
    }

    private func tick() {
        // Following words comes first: the voice leads, so the play button and hover pause do not apply.
        if isFollowingWords() {
            guard let target = followTarget else { return }
            let distance = target - scrollOffset
            guard abs(distance) > 0.5 else { return }
            // Ease: cover about a tenth of the gap each frame, so a new line glides in over a third of a second.
            scrollOffset += distance * 0.1
            return
        }
        guard !isPaused() else { return }
        let speed = CGFloat(UserDefaults.standard.object(forKey: NotchyKeys.scrollSpeed) as? Double ?? 40)
        if isAutoScrolling() || isSpeaking() {
            scrollOffset += speed * frameInterval
        }
    }

    func resetScroll() {
        followTarget = nil
        scrollOffset = 0
    }
}
