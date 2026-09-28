import AVFoundation
import Foundation

/// The calm voice that reads guided sessions aloud.
///
/// Uses the best English voice installed on the device (enhanced or premium
/// voices, when someone has downloaded them in Settings), slowed a little.
@MainActor
final class MeditationSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var finished: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    static var bestVoice: AVSpeechSynthesisVoice? {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language) || $0.language.hasPrefix("en") }
        return voices.first { $0.quality == .premium }
            ?? voices.first { $0.quality == .enhanced }
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    /// Speaks `text` and returns when it's done, or when stopped.
    func speak(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 0.95
        utterance.postUtteranceDelay = 0.2
        await withCheckedContinuation { continuation in
            finished = continuation
            synthesizer.speak(utterance)
        }
    }

    func pause() { synthesizer.pauseSpeaking(at: .word) }
    func resume() { synthesizer.continueSpeaking() }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    private func finish() {
        finished?.resume()
        finished = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}

/// A soft bell for the start and end of a session, synthesized so the app
/// ships no audio files: a low sine with a gentle overtone and a slow fade.
@MainActor
final class MeditationChime {
    /// One bell for the app, so the closing ring isn't cut off when the
    /// session screen changes underneath it.
    static let shared = MeditationChime()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        buffer = Self.makeBell(format: format)
    }

    func ring() {
        guard let buffer else { return }
        do {
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            // No chime is better than an error in the middle of a meditation.
        }
    }

    func stop() {
        player.stop()
        engine.stop()
    }

    private static func makeBell(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let seconds = 3.5
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let rate = format.sampleRate
        for frame in 0..<Int(frames) {
            let t = Double(frame) / rate
            let attack = min(1, t / 0.01)
            let decay = exp(-t * 1.4)
            let tone = sin(2 * .pi * 528 * t) * 0.6 + sin(2 * .pi * 1056 * t) * 0.18 + sin(2 * .pi * 1584 * t) * 0.07
            samples[frame] = Float(tone * attack * decay * 0.35)
        }
        return buffer
    }
}

/// Starts playback audio for a session: speech plays even with the ring
/// switch on silent (the member chose to start it), and other audio is
/// lowered rather than stopped.
enum MeditationAudioSession {
    static func begin() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    static func end() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Finished sessions, kept on this device per account. They aren't sent
/// anywhere or included in the encrypted backup.
enum MeditationLog {
    private static func url(userID: String) -> URL {
        let safeID = userID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("meditation-\(safeID).json", isDirectory: false)
    }

    static func load(userID: String) -> [MeditationSession] {
        guard let data = try? Data(contentsOf: url(userID: userID)),
              let sessions = try? JSONDecoder().decode([MeditationSession].self, from: data) else { return [] }
        return sessions
    }

    static func append(_ session: MeditationSession, userID: String) {
        var sessions = load(userID: userID)
        sessions.append(session)
        let target = url(userID: userID)
        try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(sessions.suffix(1000)) {
            try? data.write(to: target, options: [.atomic, .completeFileProtection])
        }
    }

    static func clear(userID: String) {
        try? FileManager.default.removeItem(at: url(userID: userID))
    }
}
