import Foundation

/// Biological sex, asked because some of what Vida watches is genuinely
/// sex-specific — reference ranges, which conditions are plausible, and which
/// research is worth putting first.
///
/// Kept separate from ``HealthProfile/cycleTracking`` on purpose. Sex is a
/// clinical default; whether someone has a cycle to track is a fact about
/// their body right now, and the two disagree often enough to matter.
nonisolated enum BiologicalSex: String, CaseIterable, Identifiable, Codable {
    case female, male, intersex, preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .intersex: "Intersex"
        case .preferNotToSay: "Prefer not to say"
        }
    }

    var caption: String {
        switch self {
        case .female: "Sex assigned at birth, for clinical context."
        case .male: "Sex assigned at birth, for clinical context."
        case .intersex: "Vida won't assume a reference range for you."
        case .preferNotToSay: "Vida will watch everything and assume nothing."
        }
    }
}

/// Whether there is a menstrual cycle to track.
///
/// This, and never ``BiologicalSex``, is what gates cycle features. Someone
/// post-menopause, post-hysterectomy, or on continuous contraception is female
/// with no cycle to sync, and offering it to her is a small insult from an app
/// that claims to be paying attention.
nonisolated enum CycleTracking: String, CaseIterable, Identifiable, Codable {
    case tracking, notRightNow, notTracking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tracking: "Yes, I have a cycle"
        case .notRightNow: "Not right now"
        case .notTracking: "No"
        }
    }

    var caption: String {
        switch self {
        case .tracking: "Vida will ask about bleeding and look for cycle patterns."
        case .notRightNow: "Pregnancy, contraception, a pause — Vida will leave it out for now."
        case .notTracking: "Post-menopause, surgery, or it simply doesn't apply."
        }
    }
}

/// Who a condition is relevant to, so nobody is asked to scroll past a list of
/// conditions their body cannot have.
nonisolated enum SexRelevance: String, Codable, Hashable {
    case anyone, female, male

    /// Intersex and undisclosed members see everything, because Vida has no
    /// basis for narrowing the list and guessing wrong is worse than a long one.
    func applies(to sex: BiologicalSex?) -> Bool {
        switch self {
        case .anyone: true
        case .female: sex == .female || sex == .intersex || sex == .preferNotToSay || sex == nil
        case .male: sex == .male || sex == .intersex || sex == .preferNotToSay || sex == nil
        }
    }
}

/// A chronic condition a member may be living with — or suspect they have.
///
/// VIDA LAB is not an endometriosis app. It is for people whose bodies are
/// doing something persistent that medicine has been slow to explain, and that
/// covers a wide territory: gynaecological, urological, autoimmune,
/// neurological, gut, and the very large group who have no diagnosis at all and
/// are tired of being disbelieved.
///
/// A condition never changes what Vida claims. It changes what Vida *watches*,
/// what it reads back, and which science it puts in front of them first.
nonisolated struct HealthCondition: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    /// One plain line, written for someone who already lives with this.
    let blurb: String
    /// Signals worth prioritising in the check-in and weekly report.
    let priorities: [SignalCategory]
    /// Library pieces surfaced first for this condition.
    let articleIDs: [String]
    /// Who this is offered to. Defaults to everyone, which is right for most
    /// of the catalogue — only the sex-specific entries need narrowing.
    var relevance: SexRelevance = .anyone

    static let catalog: [HealthCondition] = [
        .init(id: "endometriosis", name: "Endometriosis",
              blurb: "Tissue like the uterine lining growing where it shouldn't.",
              priorities: [.pain, .cycle, .digestion, .energy, .mood],
              articleIDs: ["endo-pain", "pain-science", "endo-research"],
              relevance: .female),
        .init(id: "adenomyosis", name: "Adenomyosis",
              blurb: "Endometrial tissue inside the muscle wall of the uterus.",
              priorities: [.pain, .cycle, .energy, .mood],
              articleIDs: ["endo-pain", "heavy-bleeding"],
              relevance: .female),
        .init(id: "pcos", name: "PCOS",
              blurb: "A metabolic and hormonal condition, not just a cycle one.",
              priorities: [.cycle, .skin, .energy, .mood, .nutrition],
              articleIDs: ["pcos-metabolic", "blood-sugar-mood"],
              relevance: .female),
        .init(id: "pmdd", name: "PMDD",
              blurb: "A severe reaction to normal hormone shifts. Not 'bad PMS'.",
              priorities: [.mood, .cycle, .energy, .focus, .stress],
              articleIDs: ["pmdd-anxiety", "luteal-energy"],
              relevance: .female),
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
        .init(id: "sleep-apnoea", name: "Sleep apnoea",
              blurb: "Breathing that stops and starts, wrecking sleep you don't remember losing.",
              priorities: [.sleep, .energy, .focus, .mood, .headache],
              articleIDs: ["sleep-pain-loop", "inflammation-fatigue"]),
        .init(id: "gout", name: "Gout",
              blurb: "Crystal-driven joint inflammation that arrives in sudden attacks.",
              priorities: [.pain, .movement, .nutrition, .sleep],
              articleIDs: ["inflammation-fatigue", "pain-science"]),
        .init(id: "low-testosterone", name: "Low testosterone",
              blurb: "Diagnosed or suspected — fatigue, low drive and lost muscle together.",
              priorities: [.energy, .mood, .movement, .focus, .sleep],
              articleIDs: ["inflammation-fatigue", "diagnostic-delay"],
              relevance: .male),
        .init(id: "prostate", name: "Prostate or urinary trouble",
              blurb: "Enlargement, prostatitis, or persistent pelvic pain.",
              priorities: [.pain, .sleep, .stress, .energy],
              articleIDs: ["pain-science", "sleep-pain-loop"],
              relevance: .male),
        .init(id: "sexual-health", name: "Erectile or sexual difficulty",
              blurb: "Frequently an early vascular signal, and worth investigating properly.",
              priorities: [.mood, .energy, .stress, .sleep],
              articleIDs: ["blood-sugar-mood", "diagnostic-delay"],
              relevance: .male),
        .init(id: "undiagnosed", name: "No diagnosis yet",
              blurb: "Something is wrong and nobody has named it. That counts.",
              priorities: [.pain, .energy, .mood, .sleep, .digestion],
              articleIDs: ["diagnostic-delay", "pain-science"])
    ]

    static func find(_ id: String) -> HealthCondition? {
        catalog.first { $0.id == id }
    }

    /// The whole catalogue, ordered so the entries most likely to apply lead.
    ///
    /// Nothing is ever removed. Filtering this list by sex withheld conditions
    /// from exactly the members most often misdiagnosed — a trans member, an
    /// intersex member, or anyone who declined the question — and a member who
    /// wants to log a condition Vida did not predict for them is not an error
    /// case. Sex affects order only, never availability.
    static func catalog(orderedFor sex: BiologicalSex?) -> [HealthCondition] {
        // Sorting the offsets alongside the elements keeps ties in catalogue
        // order; `sorted(by:)` is not guaranteed stable on its own.
        catalog.enumerated()
            .sorted { first, second in
                let firstApplies = first.element.relevance.applies(to: sex)
                let secondApplies = second.element.relevance.applies(to: sex)
                if firstApplies != secondApplies { return firstApplies }
                return first.offset < second.offset
            }
            .map(\.element)
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
    /// A condition Vida's catalogue doesn't list, typed in by the member.
    var customCondition: String = ""
    /// The symptoms they said were worst — their own priority order.
    var worstSymptoms: [SignalCategory] = []
    var goals: [HealthGoal] = []
    /// Years they have been dealing with this, if they chose to say.
    var yearsUnwell: Int?
    /// Optional, like everything else here. `nil` means never asked or
    /// declined, and Vida narrows nothing on that basis.
    var biologicalSex: BiologicalSex?
    var cycleTracking: CycleTracking?
    var completedOrientation: Bool = false

    /// Whether to ask about bleeding and look for cycle patterns.
    ///
    /// Reads `cycleTracking` and never `biologicalSex` — see ``CycleTracking``.
    var tracksCycle: Bool {
        // Deliberately no `biologicalSex` check. Inferring this from sex gets
        // the cases that matter wrong in both directions: a female member
        // with no cycle had cycle cards forced on her, and a trans or intersex
        // member who does track one had them withheld. The preference is the
        // only thing that decides.
        switch cycleTracking {
        case .tracking: return true
        case .notRightNow, .notTracking: return false
        // Members who orientated before Vida asked this. Cycle signals were
        // shown to everyone then, so assuming yes leaves their check-in
        // exactly as they left it rather than quietly removing a card they
        // use daily. Settings can correct it.
        case nil: return true
        }
    }

    /// Whether a signal is one this member should be asked about at all.
    func includes(_ category: SignalCategory) -> Bool {
        category == .cycle ? tracksCycle : true
    }

    var conditions: [HealthCondition] {
        conditionIDs.compactMap { HealthCondition.find($0) }
    }

    /// The conditions worth offering this member, narrowed by sex.
    var offeredConditions: [HealthCondition] {
        HealthCondition.catalog(orderedFor: biologicalSex)
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
        // Conditions and goals both list `.cycle` among their priorities, so
        // it has to be dropped here as well as at the check-in — otherwise it
        // arrives back through the ordering for someone who has no cycle.
        return ordered.filter(includes)
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
