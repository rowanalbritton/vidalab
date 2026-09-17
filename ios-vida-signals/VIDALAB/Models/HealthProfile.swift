import Foundation

/// A chronic condition a member may be living with — or suspect she has.
///
/// VIDA LAB is not an endometriosis app. It is for women whose bodies are doing
/// something persistent that medicine has been slow to explain, and that covers
/// a wide territory: gynaecological, autoimmune, neurological, gut, and the very
/// large group who have no diagnosis at all and are tired of being disbelieved.
///
/// A condition never changes what Vida claims. It changes what Vida *watches*,
/// what it reads back to her, and which science it puts in front of her first.
nonisolated struct HealthCondition: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    /// One plain line, written for someone who already lives with this.
    let blurb: String
    /// Signals worth prioritising in her check-in and weekly report.
    let priorities: [SignalCategory]
    /// Library pieces surfaced first for this condition.
    let articleIDs: [String]

    static let catalog: [HealthCondition] = [
        .init(id: "endometriosis", name: "Endometriosis",
              blurb: "Tissue like the uterine lining growing where it shouldn't.",
              priorities: [.pain, .cycle, .digestion, .energy, .mood],
              articleIDs: ["endo-pain", "pain-science", "endo-research"]),
        .init(id: "adenomyosis", name: "Adenomyosis",
              blurb: "Endometrial tissue inside the muscle wall of the uterus.",
              priorities: [.pain, .cycle, .energy, .mood],
              articleIDs: ["endo-pain", "heavy-bleeding"]),
        .init(id: "pcos", name: "PCOS",
              blurb: "A metabolic and hormonal condition, not just a cycle one.",
              priorities: [.cycle, .skin, .energy, .mood, .nutrition],
              articleIDs: ["pcos-metabolic", "blood-sugar-mood"]),
        .init(id: "pmdd", name: "PMDD",
              blurb: "A severe reaction to normal hormone shifts. Not 'bad PMS'.",
              priorities: [.mood, .cycle, .energy, .focus, .stress],
              articleIDs: ["pmdd-anxiety", "luteal-energy"]),
        .init(id: "migraine", name: "Migraine",
              blurb: "A brain-threshold disorder, often tied to hormones.",
              priorities: [.headache, .sleep, .cycle, .stress, .focus],
              articleIDs: ["sleep-migraine", "cgrp-migraine"]),
        .init(id: "ibs", name: "IBS or gut issues",
              blurb: "Gut-brain signalling that has become over-sensitive.",
              priorities: [.digestion, .nutrition, .stress, .pain],
              articleIDs: ["gut-brain", "microbiome-research"]),
        .init(id: "ibd", name: "Crohn's, colitis or coeliac",
              blurb: "Inflammatory or immune-driven gut disease.",
              priorities: [.digestion, .nutrition, .energy, .pain],
              articleIDs: ["gut-brain", "inflammation-fatigue"]),
        .init(id: "me-cfs", name: "ME/CFS",
              blurb: "Post-exertional malaise — where effort has a delayed cost.",
              priorities: [.energy, .sleep, .focus, .pain, .movement],
              articleIDs: ["pacing-pem", "inflammation-fatigue"]),
        .init(id: "long-covid", name: "Long COVID",
              blurb: "Multi-system symptoms persisting long after infection.",
              priorities: [.energy, .focus, .sleep, .headache, .movement],
              articleIDs: ["pacing-pem", "long-covid-research"]),
        .init(id: "fibromyalgia", name: "Fibromyalgia",
              blurb: "Widespread pain from an amplified pain-processing system.",
              priorities: [.pain, .sleep, .energy, .focus, .mood],
              articleIDs: ["pain-science", "sleep-pain-loop"]),
        .init(id: "pots", name: "POTS or dysautonomia",
              blurb: "An autonomic nervous system that misjudges upright posture.",
              priorities: [.energy, .focus, .headache, .movement, .sleep],
              articleIDs: ["pots-autonomic", "pacing-pem"]),
        .init(id: "hypermobility", name: "Hypermobility or EDS",
              blurb: "Connective tissue that is more elastic than it should be.",
              priorities: [.pain, .movement, .energy, .digestion],
              articleIDs: ["pain-science", "pots-autonomic"]),
        .init(id: "thyroid", name: "Thyroid condition",
              blurb: "Hashimoto's, Graves', or another thyroid disorder.",
              priorities: [.energy, .mood, .skin, .focus, .cycle],
              articleIDs: ["thyroid-women", "inflammation-fatigue"]),
        .init(id: "autoimmune", name: "Lupus, RA or another autoimmune",
              blurb: "An immune system attacking the body it belongs to.",
              priorities: [.pain, .energy, .skin, .focus, .movement],
              articleIDs: ["autoimmune-women", "inflammation-fatigue"]),
        .init(id: "anaemia", name: "Anaemia or low iron",
              blurb: "Common, under-tested, and a real cause of exhaustion.",
              priorities: [.energy, .cycle, .focus, .nutrition],
              articleIDs: ["iron-fatigue", "heavy-bleeding"]),
        .init(id: "interstitial-cystitis", name: "Interstitial cystitis",
              blurb: "Persistent bladder pain without an infection to blame.",
              priorities: [.pain, .digestion, .stress, .sleep],
              articleIDs: ["pain-science", "gut-brain"]),
        .init(id: "mental-health", name: "Anxiety or depression",
              blurb: "Which can be a condition of its own, or a consequence.",
              priorities: [.mood, .sleep, .energy, .focus, .stress],
              articleIDs: ["pmdd-anxiety", "sleep-pain-loop"]),
        .init(id: "undiagnosed", name: "No diagnosis yet",
              blurb: "Something is wrong and nobody has named it. That counts.",
              priorities: [.pain, .energy, .mood, .sleep, .digestion],
              articleIDs: ["diagnostic-delay", "pain-science"])
    ]

    static func find(_ id: String) -> HealthCondition? {
        catalog.first { $0.id == id }
    }
}

/// What she actually wants out of this. Goals change the app's emphasis and
/// the framing of her weekly report — someone fighting for a diagnosis needs
/// different language than someone managing a condition she already knows.
nonisolated enum HealthGoal: String, CaseIterable, Identifiable, Codable {
    case understand, believed, reducePain, moreEnergy, betterSleep
    case findTriggers, prepareAppointments, trackTreatment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .understand: "Understand what's happening"
        case .believed: "Be taken seriously"
        case .reducePain: "Have less pain"
        case .moreEnergy: "Get my energy back"
        case .betterSleep: "Sleep better"
        case .findTriggers: "Find my triggers"
        case .prepareAppointments: "Walk into appointments prepared"
        case .trackTreatment: "See if a treatment is working"
        }
    }

    var caption: String {
        switch self {
        case .understand: "Turn a year of confusing days into something readable."
        case .believed: "Evidence, in your own data, that this is real."
        case .reducePain: "Find what reliably makes it worse — and what doesn't."
        case .moreEnergy: "Learn where your energy actually goes."
        case .betterSleep: "See what your nights do to your days."
        case .findTriggers: "Test suspicions properly instead of guessing."
        case .prepareAppointments: "Turn up with dates, numbers and questions."
        case .trackTreatment: "A clear before and after, not a vague feeling."
        }
    }

    var symbol: String {
        switch self {
        case .understand: "eye"
        case .believed: "hand.raised"
        case .reducePain: "waveform.path"
        case .moreEnergy: "bolt"
        case .betterSleep: "bed.double"
        case .findTriggers: "scope"
        case .prepareAppointments: "stethoscope"
        case .trackTreatment: "chart.line.uptrend.xyaxis"
        }
    }

    /// Signals this goal makes worth watching closely.
    var priorities: [SignalCategory] {
        switch self {
        case .understand: [.energy, .mood, .pain]
        case .believed: [.pain, .energy, .cycle]
        case .reducePain: [.pain, .headache, .sleep, .stress]
        case .moreEnergy: [.energy, .sleep, .nutrition, .movement]
        case .betterSleep: [.sleep, .energy, .stress]
        case .findTriggers: [.nutrition, .stress, .sleep, .movement]
        case .prepareAppointments: [.pain, .cycle, .digestion]
        case .trackTreatment: [.pain, .energy, .mood]
        }
    }
}

/// Everything the member told Vida about herself during orientation. All of it
/// is optional and all of it is editable later — nobody should be locked into
/// a description of their body that they gave on day one.
nonisolated struct HealthProfile: Codable, Hashable {
    var conditionIDs: [String] = []
    /// A condition Vida's catalogue doesn't list, typed by her.
    var customCondition: String = ""
    /// The symptoms she said were worst — her own priority order.
    var worstSymptoms: [SignalCategory] = []
    var goals: [HealthGoal] = []
    /// Years she has been dealing with this, if she chose to say.
    var yearsUnwell: Int?
    var completedOrientation: Bool = false

    var conditions: [HealthCondition] {
        conditionIDs.compactMap { HealthCondition.find($0) }
    }

    var hasAnyCondition: Bool {
        !conditionIDs.isEmpty || !customCondition.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Human list of her conditions, including anything she typed herself.
    var conditionNames: [String] {
        var names = conditions.map(\.name)
        let custom = customCondition.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty { names.append(custom) }
        return names
    }

    var conditionSummary: String {
        let names = conditionNames
        switch names.count {
        case 0: return "No condition recorded"
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return "\(names[0]) and \(names.count - 1) more"
        }
    }

    /// The signals Vida should watch hardest, in priority order: what she said
    /// hurts most, then what her conditions imply, then what her goals need.
    /// Deduplicated, so a signal named twice doesn't crowd out everything else.
    var focusSignals: [SignalCategory] {
        var ordered: [SignalCategory] = []
        var seen: Set<SignalCategory> = []

        func add(_ categories: [SignalCategory]) {
            for category in categories where !seen.contains(category) {
                seen.insert(category)
                ordered.append(category)
            }
        }

        add(worstSymptoms)
        for condition in conditions { add(condition.priorities) }
        for goal in goals { add(goal.priorities) }
        add([.energy, .mood, .sleep])
        return ordered
    }

    /// Article IDs to surface first in the Library, from her conditions.
    var recommendedArticleIDs: [String] {
        var ids: [String] = []
        for condition in conditions {
            for id in condition.articleIDs where !ids.contains(id) {
                ids.append(id)
            }
        }
        return ids
    }
}
