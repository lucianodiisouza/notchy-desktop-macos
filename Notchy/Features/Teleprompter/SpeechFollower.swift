import AVFoundation
import Combine
import Foundation
import NaturalLanguage
import Speech

/// "Follow my words": recognizes speech on this Mac and finds where in the script you are, so the prompter can keep
/// that line in view. Recognition runs on-device only; no audio or text leaves the Mac.
///
/// Matching compares the last few recognized words with a window of the script just around the current position, with
/// some slack for misheard words, skipped words and small repeats. It never jumps far ahead on a single common word.
@MainActor
final class SpeechFollower: ObservableObject {
    enum Status: Equatable {
        /// Not following (voice off, or "voice level" mode).
        case idle
        /// Waiting on the speech recognition prompt.
        case askingPermission
        /// Speech recognition is off for Notchy in Privacy & Security.
        case denied
        /// No on-device recognizer for the script's language.
        case unsupportedLanguage(String)
        /// Downloading the language's speech model (once per language, macOS 26 and later).
        case downloadingLanguage(String)
        case listening
    }

    @Published private(set) var status: Status = .idle
    /// UTF-16 range, in the script, of the word last heard.
    @Published private(set) var currentWordRange: NSRange?
    /// The language being recognized, e.g. "pt-BR".
    @Published private(set) var activeLocale: Locale?

    private struct Word {
        let key: String
        let range: NSRange
    }

    private var script = ""
    private var words: [Word] = []
    /// Index in `words` of the word last heard; -1 before the first one.
    private var cursor = -1

    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    /// The macOS 26 engine, when it is the one running (typed Any so the class can load on older systems).
    private var transcriber: AnyObject?
    private var startTask: Task<Void, Never>?
    private let feed = AudioFeed()
    private var wantsToListen = false
    private weak var audio: AudioMonitor?

    // MARK: - Script

    /// The text on the prompter. Keeps the reading position when the text is edited.
    func setScript(_ text: String) {
        guard text != script else { return }
        let location = currentWordRange?.location
        script = text
        words = Self.tokenize(text)
        if let location {
            cursor = (words.firstIndex { $0.range.location >= location } ?? words.count) - 1
            currentWordRange = cursor >= 0 ? words[cursor].range : nil
        } else {
            cursor = -1
            currentWordRange = nil
        }
        if wantsToListen, let audio {
            // A script in another language needs another recognizer.
            let current = activeLocale?.identifier
            Task { [weak self] in
                guard let self else { return }
                let locale = await self.resolvedLocale()
                if locale.identifier != current, self.wantsToListen {
                    self.stop()
                    self.start(audio: audio)
                }
            }
        }
    }

    /// Back to the top, e.g. ⌘0.
    func reset() {
        cursor = -1
        currentWordRange = nil
    }

    /// The reader clicked a word: continue from there.
    func jump(toCharacter location: Int) {
        guard let index = words.firstIndex(where: { NSMaxRange($0.range) >= location }) else { return }
        cursor = index - 1
        currentWordRange = index > 0 ? words[index - 1].range : nil
    }

    // MARK: - Listening

    func start(audio: AudioMonitor) {
        self.audio = audio
        wantsToListen = true
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            beginRecognition()
        case .notDetermined:
            status = .askingPermission
            SFSpeechRecognizer.requestAuthorization { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.wantsToListen else { return }
                    if SFSpeechRecognizer.authorizationStatus() == .authorized {
                        self.beginRecognition()
                    } else {
                        self.status = .denied
                    }
                }
            }
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .denied
        }
    }

    func stop() {
        wantsToListen = false
        startTask?.cancel()
        startTask = nil
        audio?.setBufferHandler(nil)
        feed.consumer = nil
        task?.cancel()
        task = nil
        recognizer = nil
        if #available(macOS 26.0, *), let engine = transcriber as? TranscriberEngine {
            Task { await engine.stop() }
        }
        transcriber = nil
        status = .idle
    }

    private func beginRecognition() {
        let feed = self.feed
        audio?.setBufferHandler { buffer in feed.push(buffer) }
        startTask = Task { [weak self] in
            guard let self else { return }
            let locale = await self.resolvedLocale()
            guard !Task.isCancelled, self.wantsToListen else { return }
            self.activeLocale = locale
            let name = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            if #available(macOS 26.0, *), SpeechTranscriber.isAvailable,
               await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil {
                await self.beginTranscriber(locale: locale, name: name)
            } else {
                self.beginLegacy(locale: locale, name: name)
            }
        }
    }

    /// macOS 26: SpeechAnalyzer, which recognizes many more languages offline and downloads each one once.
    @available(macOS 26.0, *)
    private func beginTranscriber(locale: Locale, name: String) async {
        let engine = TranscriberEngine()
        transcriber = engine
        do {
            try await engine.start(
                locale: locale,
                contextualStrings: contextualStrings(),
                feed: feed,
                onDownload: { [weak self] in self?.status = .downloadingLanguage(name) },
                onText: { [weak self] text in self?.follow(text) })
            guard wantsToListen, transcriber === engine else { return await engine.stop() }
            status = .listening
        } catch {
            AppLogger.error("Speech analyzer failed for \(locale.identifier): \(error)")
            guard transcriber === engine else { return }
            transcriber = nil
            status = .unsupportedLanguage(name)
        }
    }

    /// Before macOS 26: SFSpeechRecognizer, on-device only.
    private func beginLegacy(locale: Locale, name: String) {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else {
            status = .unsupportedLanguage(name)
            return
        }
        recognizer.queue = .main
        self.recognizer = recognizer
        startLegacyTask()
        status = .listening
    }

    /// One recognition task. It ends on its own after a long stretch or a pause; a new one picks up where it left off.
    private func startLegacyTask() {
        guard wantsToListen, let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        request.addsPunctuation = false
        request.contextualStrings = contextualStrings()
        feed.consumer = { buffer in request.append(buffer) }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let result {
                    self.follow(result.bestTranscription.formattedString)
                }
                if error != nil || result?.isFinal == true {
                    request.endAudio()
                    self.task = nil
                    // Start listening again right away; the next words go to the new task.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self, self.wantsToListen, self.task == nil, self.recognizer != nil else { return }
                        self.startLegacyTask()
                    }
                }
            }
        }
    }

    /// Script words the recognizer might not know (names, jargon), so it favors them.
    private func contextualStrings() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        (script as NSString).enumerateSubstrings(in: NSRange(location: 0, length: (script as NSString).length),
                                                 options: .byWords) { word, _, _, stop in
            guard let word, word.count >= 5 else { return }
            let isName = word.first?.isUppercase == true
            if (isName || word.count >= 9), seen.insert(word.lowercased()).inserted {
                out.append(word)
            }
            if out.count >= 100 { stop.pointee = true }
        }
        return out
    }

    // MARK: - Language

    /// The language picked in Settings, or the script's own language, among those the Mac recognizes on-device.
    private func resolvedLocale() async -> Locale {
        if let chosen = UserDefaults.standard.string(forKey: NotchyKeys.speechLocale), !chosen.isEmpty {
            return Locale(identifier: chosen)
        }
        return await Self.locale(forText: script)
    }

    static func locale(forText text: String) async -> Locale {
        let supported = await availableLocales()
        let current = Locale.current
        guard let language = NLLanguageRecognizer.dominantLanguage(for: String(text.prefix(2000)))?.rawValue else {
            return current
        }
        let base = Locale(identifier: language).language.languageCode?.identifier ?? language
        let candidates = supported.filter { $0.language.languageCode?.identifier == base }
        if candidates.isEmpty { return Locale(identifier: language) }
        // Prefer the Mac's own region (pt-BR over pt-PT for a Brazilian Mac), then the most common variant.
        if let sameRegion = candidates.first(where: { $0.region == current.region }) { return sameRegion }
        let preferred = ["en-US", "pt-BR", "es-ES", "fr-FR", "de-DE", "it-IT", "zh-CN", "ja-JP", "ko-KR"]
        if let common = candidates.first(where: { preferred.contains($0.identifier(.bcp47)) }) { return common }
        return candidates.sorted { $0.identifier < $1.identifier }[0]
    }

    /// Languages this Mac recognizes without a network connection (on macOS 26, after a one-time download).
    static func availableLocales() async -> [Locale] {
        var locales: [Locale]
        if #available(macOS 26.0, *), SpeechTranscriber.isAvailable {
            locales = await SpeechTranscriber.supportedLocales
        } else {
            locales = SFSpeechRecognizer.supportedLocales()
                .filter { SFSpeechRecognizer(locale: $0)?.supportsOnDeviceRecognition == true }
        }
        return locales.sorted {
            let a = Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier
            let b = Locale.current.localizedString(forIdentifier: $1.identifier) ?? $1.identifier
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    // MARK: - Matching

    /// How many recognized words at the end of the transcript to line up with the script.
    private static let tailLength = 8
    /// How far behind and ahead of the current word to look.
    private static let lookBehind = 12
    private static let lookAhead = 60

    func follow(_ transcript: String) {
        guard !words.isEmpty else { return }
        let spoken = Self.tokenize(transcript).map(\.key)
        let tail = Array(spoken.suffix(Self.tailLength))
        guard !tail.isEmpty else { return }

        let low = max(0, cursor - Self.lookBehind)
        let high = min(words.count - 1, cursor + Self.lookAhead)
        guard low <= high else { return }

        var best: (index: Int, score: Double)?
        for end in low...high {
            // The script word must be one of the last two heard; the very last may still be half-recognized.
            let lastMatches = Self.similar(tail[tail.count - 1], words[end].key)
            let secondLastMatches = tail.count > 1 && Self.similar(tail[tail.count - 2], words[end].key)
            guard lastMatches || secondLastMatches else { continue }
            let matched = alignmentScore(tail: lastMatches ? tail : Array(tail.dropLast()), endingAt: end)
            // Prefer the spot just after the current word; going backwards costs more than going ahead.
            let distance = end - (cursor + 1)
            let penalty = distance >= 0 ? Double(distance) * 0.04 : Double(-distance) * 0.15
            let score = matched - penalty
            if score > (best?.score ?? 0) { best = (end, score) }
        }

        guard let best else { return }
        let step = best.index - cursor
        // One heard word is enough only right next to where we are; further away needs more agreement.
        let needed: Double = (1...3).contains(step) ? 0.9 : (step <= 0 ? 3.4 : 1.8)
        guard best.score >= needed, best.index != cursor else { return }
        cursor = best.index
        currentWordRange = words[best.index].range
    }

    /// Weighted count of `tail` words that line up, in order, with the script words ending at `end`
    /// (a longest-common-subsequence over a short window).
    private func alignmentScore(tail: [String], endingAt end: Int) -> Double {
        let start = max(0, end - tail.count - 4)
        let window = words[start...end].map(\.key)
        let m = tail.count
        let n = window.count
        guard m > 0, n > 0 else { return 0 }
        var dp = Array(repeating: Array(repeating: 0.0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if Self.similar(tail[i - 1], window[j - 1]) {
                    dp[i][j] = dp[i - 1][j - 1] + Self.weight(tail[i - 1])
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        return dp[m][n]
    }

    /// Short words ("a", "de", "the") say little about where you are.
    private static func weight(_ word: String) -> Double {
        word.count <= 2 ? 0.4 : (word.count <= 3 ? 0.7 : 1)
    }

    static func similar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let shorter = min(a.count, b.count)
        guard shorter >= 4 else { return false }
        // A word cut short by the recognizer, or a plural/verb ending.
        if a.hasPrefix(b) || b.hasPrefix(a) { return abs(a.count - b.count) <= 3 }
        return editDistance(a, b, limit: shorter >= 8 ? 2 : 1) != nil
    }

    /// Levenshtein distance when it is at most `limit`, nil otherwise.
    private static func editDistance(_ a: String, _ b: String, limit: Int) -> Int? {
        let x = Array(a), y = Array(b)
        guard abs(x.count - y.count) <= limit else { return nil }
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var current = [i] + Array(repeating: 0, count: y.count)
            var rowMin = current[0]
            for j in 1...y.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
                rowMin = min(rowMin, current[j])
            }
            if rowMin > limit { return nil }
            previous = current
        }
        return previous[y.count] <= limit ? previous[y.count] : nil
    }

    /// Words with their ranges, keyed lowercase without accents or punctuation so "Olá," matches "ola".
    private static func tokenize(_ text: String) -> [Word] {
        var out: [Word] = []
        let ns = text as NSString
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byWords, .localized]) { word, range, _, _ in
            guard let word else { return }
            let key = word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                .filter { $0.isLetter || $0.isNumber }
            if !key.isEmpty { out.append(Word(key: key, range: range)) }
        }
        return out
    }
}

/// Hands microphone buffers from the audio thread to whichever recognizer is running. The consumer changes each time a
/// recognition task ends and a new one starts.
private final class AudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var _consumer: ((AVAudioPCMBuffer) -> Void)?

    var consumer: ((AVAudioPCMBuffer) -> Void)? {
        get { lock.withLock { _consumer } }
        set { lock.withLock { _consumer = newValue } }
    }

    func push(_ buffer: AVAudioPCMBuffer) {
        consumer?(buffer)
    }
}

/// The macOS 26 recognizer: SpeechTranscriber inside a SpeechAnalyzer, fed through an AsyncStream.
@available(macOS 26.0, *)
@MainActor
private final class TranscriberEngine {
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    func start(
        locale: Locale,
        contextualStrings: [String],
        feed: AudioFeed,
        onDownload: @escaping @MainActor () -> Void,
        onText: @escaping @MainActor (String) -> Void
    ) async throws {
        let transcriber = SpeechTranscriber(
            locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        let modules: [any SpeechModule] = [transcriber]

        // The language model is downloaded once and then works offline.
        if await AssetInventory.status(forModules: modules) != .installed {
            if !(await AssetInventory.reservedLocales).contains(where: { $0.identifier == locale.identifier }) {
                _ = try? await AssetInventory.reserve(locale: locale)
            }
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                onDownload()
                try await request.downloadAndInstall()
            }
        }

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
            throw CocoaError(.featureUnsupported)
        }
        let analyzer = SpeechAnalyzer(modules: modules)
        self.analyzer = analyzer
        let context = AnalysisContext()
        context.contextualStrings = [.general: contextualStrings]
        try? await analyzer.setContext(context)
        try await analyzer.prepareToAnalyze(in: format)

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.continuation = continuation
        let converter = BufferConverter(to: format)
        feed.consumer = { buffer in
            if let converted = converter.convert(buffer) {
                continuation.yield(AnalyzerInput(buffer: converted))
            }
        }

        // Finished stretches come in once; the stretch still being spoken is replaced as it firms up.
        resultsTask = Task { @MainActor in
            var finished = ""
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        finished = String((finished + " " + text).suffix(400))
                        onText(finished)
                    } else {
                        onText(finished + " " + text)
                    }
                }
            } catch {
                AppLogger.error("Speech results ended: \(error)")
            }
        }
        try await analyzer.start(inputSequence: stream)
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        await analyzer?.cancelAndFinishNow()
        analyzer = nil
    }
}

/// Converts microphone buffers to the format the analyzer wants. Runs on the audio thread only.
private final class BufferConverter: @unchecked Sendable {
    private let format: AVAudioFormat
    private var converter: AVAudioConverter?

    init(to format: AVAudioFormat) {
        self.format = format
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        if converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: format)
        }
        guard let converter else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var delivered = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if delivered {
                status.pointee = .noDataNow
                return nil
            }
            delivered = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && output.frameLength > 0 ? output : nil
    }
}
