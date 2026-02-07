import AVFoundation
import Combine
import SwiftUI

/// Sensitivity 0–100 in UserDefaults; we map to threshold (high sensitivity = low threshold).
/// Call from main thread only (UserDefaults read).
private func currentSpeechThreshold() -> Float {
    let s = UserDefaults.standard.double(forKey: NotchyKeys.micSensitivity)
    let normalized = max(0, min(100, s))
    return Float(0.08 - (normalized / 100) * 0.075)
}

final class AudioMonitor: ObservableObject {
    @Published private(set) var isSpeaking = false

    private let audioEngine = AVAudioEngine()
    private let silenceDurationToStop: TimeInterval = 0.6
    private var lastSpeechTime = Date()
    private var isConfigured = false
    /// Cached threshold; updated on main thread so we never read UserDefaults from the audio tap callback.
    private var cachedSpeechThreshold: Float = 0.04

    func start() {
        guard !isConfigured else { return }

        // Checar status primeiro: se já autorizado, não pedir de novo (evita diálogo a cada launch).
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            configureAndStart()
        case .denied:
            break
        case .notDetermined:
            if #available(macOS 14.0, *) {
                AVAudioApplication.requestRecordPermission { [weak self] allowed in
                    DispatchQueue.main.async {
                        if allowed {
                            self?.configureAndStart()
                        }
                    }
                }
            } else {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] allowed in
                    DispatchQueue.main.async {
                        if allowed {
                            self?.configureAndStart()
                        }
                    }
                }
            }
        case .restricted:
            break
        @unknown default:
            break
        }
    }

    func stop() {
        guard isConfigured else { return }
        audioEngine.stop()
        isConfigured = false
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }

    private func configureAndStart() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try audioEngine.start()
            isConfigured = true
            cachedSpeechThreshold = currentSpeechThreshold()
        } catch {
            // Permission denied or device error
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var sum: Float = 0
        for ch in 0..<channelCount {
            for i in 0..<frameLength {
                let s = channelData[ch][i]
                sum += abs(s)
            }
        }
        let count = frameLength * channelCount
        let average = count > 0 ? sum / Float(count) : 0

        let threshold = cachedSpeechThreshold
        let speaking = average > threshold
        let now = Date()

        if speaking {
            lastSpeechTime = now
        }

        let silenceDuration = now.timeIntervalSince(lastSpeechTime)
        let shouldBeSpeaking = speaking || silenceDuration < silenceDurationToStop

        DispatchQueue.main.async { [weak self] in
            self?.cachedSpeechThreshold = currentSpeechThreshold()
            self?.isSpeaking = shouldBeSpeaking
        }
    }

    /// Lista nomes dos dispositivos de entrada de áudio (para exibir nas configurações).
    /// O Notchy usa sempre o microfone padrão do sistema; o usuário altera em Ajustes > Som.
    static func inputDeviceNames() -> [String] {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.builtInMicrophone, .external]
        } else {
            deviceTypes = [.builtInMicrophone]
        }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )
        return session.devices.map { $0.localizedName }
    }
}
