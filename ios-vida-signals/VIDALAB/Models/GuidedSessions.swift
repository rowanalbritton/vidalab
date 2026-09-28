import Foundation

// Sessions with a guide: short scripted meditations recorded ahead of time in
// ten AI voices, streamed from Supabase Storage and cached on the phone. The
// scripts ship in the app too (Content/Meditations), so the words are always
// on screen and the device's own voice can read them if a file won't download.

/// One of the AI voices. Never a recording or likeness of a real person.
nonisolated struct MeditationGuide: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    var isPremium: Bool = false

    enum CodingKeys: String, CodingKey { case id, name, description, isPremium }

    init(id: String, name: String, description: String, isPremium: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.isPremium = isPremium
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
    }
}

/// A scripted session. The same script is rendered once per guide.
nonisolated struct VoicedSession: Decodable, Identifiable, Hashable, Sendable {
    nonisolated struct Segment: Decodable, Hashable, Sendable {
        let text: String
        /// Quiet after the line, in seconds.
        let pause: Double
    }

    let id: String
    let title: String
    let summary: String
    let minutes: Int
    let moment: String
    var isPremium: Bool = false
    let segments: [Segment]

    enum CodingKeys: String, CodingKey { case id, title, summary, minutes, moment, isPremium, segments }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        minutes = try container.decode(Int.self, forKey: .minutes)
        moment = try container.decodeIfPresent(String.self, forKey: .moment) ?? "any"
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        segments = try container.decode([Segment].self, forKey: .segments)
    }

    /// The same session for the device's own voice, when the audio isn't available.
    var fallbackScript: GuidedScript {
        GuidedScript(title: title, segments: segments.map { .init(text: $0.text, pauseSeconds: $0.pause) }, tip: nil)
    }
}

/// When each line is spoken in a rendered file, so the words on screen follow the voice.
nonisolated struct VoicedCue: Codable, Hashable, Sendable {
    let start: Double
    let end: Double
}

nonisolated struct VoicedManifest: Codable, Sendable {
    nonisolated struct Entry: Codable, Hashable, Sendable {
        let path: String
        let duration: Double
        let cues: [VoicedCue]
    }

    let version: Int
    /// Guide ID, then session ID.
    let guides: [String: [String: Entry]]

    func entry(guide: String, session: String) -> Entry? { guides[guide]?[session] }
}

nonisolated enum VoicedLibrary {
    static let bucket = "meditation-audio"
    static let sessionOrder = ["arrive", "reset", "clear-the-fog", "flare-day-body-scan", "wind-down"]

    static func loadGuides(bundle: Bundle = .main) -> [MeditationGuide] {
        guard let data = resource("guides", bundle: bundle) else { return [] }
        return (try? JSONDecoder().decode([MeditationGuide].self, from: data)) ?? []
    }

    static func loadSessions(bundle: Bundle = .main) -> [VoicedSession] {
        sessionOrder.compactMap { id in
            resource(id, bundle: bundle).flatMap { try? JSONDecoder().decode(VoicedSession.self, from: $0) }
        }
    }

    /// Resources in a synchronized folder usually land at the bundle root, but
    /// the folder path is checked too in case it's ever added by reference.
    private static func resource(_ name: String, bundle: Bundle) -> Data? {
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Content/Meditations")
        return url.flatMap { try? Data(contentsOf: $0) }
    }

    /// The line being spoken, or the last one spoken, at `time`.
    static func cueIndex(at time: Double, in cues: [VoicedCue]) -> Int? {
        cues.lastIndex { $0.start <= time + 0.05 }
    }

    /// A session that fits the time of day, falling back to a free one.
    static func suggestedID(for moment: MeditationMoment, isPlus: Bool, sessions: [VoicedSession]) -> String? {
        let preferred: String = switch moment {
        case .morning: "clear-the-fog"
        case .midday: "reset"
        case .evening: "arrive"
        case .night: "wind-down"
        }
        if let match = sessions.first(where: { $0.id == preferred }), isPlus || !match.isPremium { return match.id }
        return sessions.first { !$0.isPremium }?.id
    }
}
