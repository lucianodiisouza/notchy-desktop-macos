import Combine
import SwiftUI

/// "voiceMode" values.
enum VoiceMode: String, CaseIterable {
    /// Scroll at the set speed while there is sound on the microphone.
    case level
    /// Recognize the words and keep the line being read in view.
    case follow
}

/// Shared state for the app so the notch window, the menu bar and Settings use the same instances.
@MainActor
final class NotchyState: ObservableObject {
    static let shared = NotchyState()

    let windowController = FloatingWindowController()
    let audioMonitor = AudioMonitor()
    let scrollController = ScrollController()
    let speechFollower = SpeechFollower()

    private var cancellables = Set<AnyCancellable>()
    private var appliedMicrophone: String?

    private init() {
        let defaults = UserDefaults.standard
        scrollController.isAutoScrolling = { defaults.bool(forKey: NotchyKeys.autoScrollPlaying) }
        scrollController.isFollowingWords = { [weak self] in
            guard let self else { return false }
            return MainActor.assumeIsolated { self.isListening && self.voiceMode == .follow }
        }
        scrollController.isSpeaking = { [weak self] in
            guard let self else { return false }
            return MainActor.assumeIsolated { self.isListening && self.voiceMode == .level && self.audioMonitor.isSpeaking }
        }

        // The follower reads whatever script is on the prompter.
        let store = ScriptStore.shared
        Publishers.CombineLatest(store.$scripts, store.$selectedScriptId)
            .map { _, _ in store.currentScriptBody }
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] body in self?.speechFollower.setScript(body) }
            .store(in: &cancellables)

        // Voice on/off, mode, microphone, language and play all live in UserDefaults. Every write to defaults posts the
        // same notification (window drags and sliders write many a second), so act only when one of these changed.
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .map { _ in VoiceSettings.current }
            .removeDuplicates()
            .sink { [weak self] _ in self?.applyVoiceSettings() }
            .store(in: &cancellables)

        // "Voice level" only moves the text while there is sound; keep the frame timer off through the silences.
        audioMonitor.$isSpeaking
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateScrollActivity() }
            }
            .store(in: &cancellables)

        // Folded into the notch the script is out of sight: stop listening until it opens again.
        windowController.$isExpanded
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.applyVoiceSettings() }
            }
            .store(in: &cancellables)
    }

    /// The settings that decide whether the microphone, the word follower and the scroll timer run.
    private struct VoiceSettings: Equatable {
        let listen: Bool
        let mode: String?
        let microphone: String?
        let locale: String?
        let playing: Bool

        static var current: VoiceSettings {
            let d = UserDefaults.standard
            return VoiceSettings(
                listen: d.object(forKey: NotchyKeys.voiceControlEnabled) as? Bool ?? true,
                mode: d.string(forKey: NotchyKeys.voiceMode),
                microphone: d.string(forKey: NotchyKeys.preferredMicrophoneUID),
                locale: d.string(forKey: NotchyKeys.speechLocale),
                playing: d.bool(forKey: NotchyKeys.autoScrollPlaying))
        }
    }

    var isListening: Bool {
        UserDefaults.standard.object(forKey: NotchyKeys.voiceControlEnabled) as? Bool ?? true
    }

    var voiceMode: VoiceMode {
        VoiceMode(rawValue: UserDefaults.standard.string(forKey: NotchyKeys.voiceMode) ?? "") ?? .level
    }

    private var appliedMode: VoiceMode?
    private var appliedLocale: String?
    /// False until the prompter is on screen, so the microphone prompt does not show before there is anything to read.
    private var isPrompterActive = false

    func prompterDidAppear() {
        isPrompterActive = true
        applyVoiceSettings()
    }

    func prompterDidDisappear() {
        isPrompterActive = false
        applyVoiceSettings()
    }

    /// Starts or stops the microphone, the word follower and the scroll timer to match Settings and what is on screen.
    func applyVoiceSettings() {
        let defaults = UserDefaults.standard
        let onScreen = isPrompterActive && windowController.isExpanded
        let listen = onScreen && isListening
        let mode = voiceMode
        let microphone = defaults.string(forKey: NotchyKeys.preferredMicrophoneUID) ?? ""
        let locale = defaults.string(forKey: NotchyKeys.speechLocale) ?? ""
        updateScrollActivity()

        guard listen else {
            speechFollower.stop()
            audioMonitor.stop()
            appliedMode = nil
            return
        }
        if microphone != appliedMicrophone {
            appliedMicrophone = microphone
            audioMonitor.restart()
        }
        audioMonitor.start()
        if mode == .follow {
            if appliedMode != .follow || locale != appliedLocale || speechFollower.status == .idle {
                speechFollower.stop()
                speechFollower.start(audio: audioMonitor)
            }
        } else if appliedMode == .follow {
            speechFollower.stop()
        }
        appliedMode = mode
        appliedLocale = locale
    }

    /// Runs the scroll timer only while something can move the text: play, speech in "voice level", or "follow my words".
    private func updateScrollActivity() {
        let onScreen = isPrompterActive && windowController.isExpanded
        let listen = onScreen && isListening
        let playing = UserDefaults.standard.bool(forKey: NotchyKeys.autoScrollPlaying)
        let voiceMoves = listen && (voiceMode == .follow || audioMonitor.isSpeaking)
        scrollController.isActive = onScreen && (playing || voiceMoves)
    }

    /// Back to the top of the script (⌘0).
    func resetReading() {
        scrollController.resetScroll()
        speechFollower.reset()
    }
}
