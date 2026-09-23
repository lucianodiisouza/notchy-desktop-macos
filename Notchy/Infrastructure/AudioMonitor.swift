import AVFoundation
import AudioToolbox
import Combine
import CoreAudio

/// Listens to the microphone. It tells the teleprompter when you are speaking (by sound level) and hands every buffer
/// to whoever wants the audio itself, which is how "follow my words" gets it for speech recognition.
final class AudioMonitor: ObservableObject {
    @Published private(set) var isSpeaking = false
    /// True while the engine runs.
    @Published private(set) var isRunning = false
    /// macOS blocks the microphone for Notchy (denied or restricted in Privacy & Security).
    @Published private(set) var isDenied = false

    private let audioEngine = AVAudioEngine()
    private let silenceDurationToStop: TimeInterval = 0.6
    private var configurationObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?

    /// Touched from the audio thread; guarded by `lock`.
    private let lock = NSLock()
    private var speechThreshold: Float = 0.04
    private var lastSpeechTime = Date.distantPast
    private var lastReportedSpeaking = false
    private var bufferHandler: ((AVAudioPCMBuffer) -> Void)?

    init() {
        speechThreshold = Self.threshold()
        // The sensitivity slider writes to UserDefaults; pick the new value up without reading defaults on the audio thread.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let value = Self.threshold()
            self.lock.withLock { self.speechThreshold = value }
        }
    }

    deinit {
        [configurationObserver, defaultsObserver].compactMap { $0 }.forEach(NotificationCenter.default.removeObserver)
    }

    /// Sensitivity 0–100 maps to a level threshold: high sensitivity, low threshold.
    private static func threshold() -> Float {
        let stored = UserDefaults.standard.object(forKey: NotchyKeys.micSensitivity) as? Double ?? 50
        let normalized = max(0, min(100, stored))
        return Float(0.08 - (normalized / 100) * 0.075)
    }

    /// Receives every microphone buffer on the audio thread while the engine runs. nil stops the feed.
    func setBufferHandler(_ handler: ((AVAudioPCMBuffer) -> Void)?) {
        lock.withLock { bufferHandler = handler }
    }

    func start() {
        guard !isRunning else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            isDenied = false
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] allowed in
                DispatchQueue.main.async {
                    self?.isDenied = !allowed
                    if allowed { self?.configureAndStart() }
                }
            }
        case .denied, .restricted:
            isDenied = true
        @unknown default:
            break
        }
    }

    func stop() {
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationObserver = nil
        }
        guard isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRunning = false
        lock.withLock {
            lastReportedSpeaking = false
            lastSpeechTime = .distantPast
        }
        isSpeaking = false
    }

    /// Stop and start again, e.g. after picking another microphone.
    func restart() {
        let wasRunning = isRunning
        stop()
        if wasRunning { start() }
    }

    private func configureAndStart() {
        let inputNode = audioEngine.inputNode
        selectPreferredDevice(on: inputNode)

        let format = inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            AppLogger.error("The microphone has no usable input format")
            return
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRunning = true
            observeConfigurationChanges()
        } catch {
            inputNode.removeTap(onBus: 0)
            AppLogger.error("Could not start the microphone: \(error)")
        }
    }

    /// Uses the microphone picked in Settings for Notchy only. The system's default input is left alone.
    private func selectPreferredDevice(on inputNode: AVAudioInputNode) {
        guard let uid = UserDefaults.standard.string(forKey: NotchyKeys.preferredMicrophoneUID), !uid.isEmpty,
              var deviceID = AudioDeviceList.deviceID(for: uid),
              let unit = inputNode.audioUnit else { return }
        let status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
            &deviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
        if status != noErr {
            AppLogger.error("Could not switch to the chosen microphone (\(status)); using the system default")
        }
    }

    /// Plugging in or removing a device reconfigures the engine and stops it; start it again on the new setup.
    private func observeConfigurationChanges() {
        guard configurationObserver == nil else { return }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.stop()
            self.start()
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        let (threshold, handler) = lock.withLock { (speechThreshold, bufferHandler) }
        handler?(buffer)

        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        var sum: Float = 0
        for ch in 0..<channelCount {
            let samples = channelData[ch]
            for i in 0..<frameLength {
                sum += abs(samples[i])
            }
        }
        let count = frameLength * channelCount
        let average = count > 0 ? sum / Float(count) : 0

        let now = Date()
        let changed: Bool = lock.withLock {
            if average > threshold { lastSpeechTime = now }
            let speaking = now.timeIntervalSince(lastSpeechTime) < silenceDurationToStop
            guard speaking != lastReportedSpeaking else { return false }
            lastReportedSpeaking = speaking
            return true
        }
        // Publish only when it flips, not ~40 times a second.
        if changed {
            let speaking = lock.withLock { lastReportedSpeaking }
            DispatchQueue.main.async { [weak self] in
                self?.isSpeaking = speaking
            }
        }
    }

    /// Input devices for the microphone picker (UID + name). Empty preferredMicrophoneUID = system default.
    static func inputDevicesForPicker() -> [AudioDeviceList.Item] {
        AudioDeviceList.inputDevices()
    }
}
