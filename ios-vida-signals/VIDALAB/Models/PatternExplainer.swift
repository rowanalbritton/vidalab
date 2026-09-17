import Foundation

/// How much weight a connection has earned, based on both how strong it is and
/// how many days sit behind it. Strength alone is not trustworthy on six days.
nonisolated enum PatternConfidence: String {
    case early = "Early signal"
    case watching = "Worth watching"
    case consistent = "Consistent"

    var blurb: String {
        switch self {
        case .early:
            "Real, but thin. A handful of unusual days could still be driving this."
        case .watching:
            "Holding up so far. Enough days that it's unlikely to be noise alone."
        case .consistent:
            "This has stayed true across weeks of your data, not just a rough patch."
        }
    }
}

/// The two halves of a connection, compared the way a lab would compare arms:
/// split the days by the first signal, then look at what the second one did.
nonisolated struct ArmComparison {
    let driver: SignalCategory
    let outcome: SignalCategory
    let highLabel: String
    let lowLabel: String
    let highAverage: Double
    let lowAverage: Double
    let highDays: Int
    let lowDays: Int

    var difference: Double { highAverage - lowAverage }

    /// Difference as a share of the lower arm, for "about a third less" phrasing.
    var percentDifference: Double? {
        let base = max(lowAverage, highAverage)
        guard base > 0.6 else { return nil }
        return abs(difference) / base * 100
    }

    /// Whether the high-driver arm is the more comfortable place to be.
    var highArmIsBetter: Bool {
        outcome.higherIsBetter ? difference > 0 : difference < 0
    }
}

/// Plain-language meaning for a connection: why two things might move together,
/// and what a person can actually do about it.
///
/// Every entry is written as a possibility, never a cause. Correlation in a
/// personal log cannot establish direction, and the copy here never pretends
/// otherwise — it offers the common physiological explanation and then points
/// at the Lab, which is the only honest way to test direction.
nonisolated struct PatternExplanation {
    let mechanism: String
    let tries: [String]
    let articleID: String?
}

nonisolated enum PatternExplainer {

    /// Everyday noun for a signal, used when a title would read stiffly mid-sentence.
    static func noun(_ category: SignalCategory) -> String {
        switch category {
        case .cycle: "bleeding"
        case .sleep: "sleep"
        case .energy: "energy"
        case .mood: "mood"
        case .pain: "pain"
        case .headache: "head pain"
        case .digestion: "gut comfort"
        case .skin: "skin comfort"
        case .focus: "focus"
        case .movement: "movement"
        case .nutrition: "nourishment"
        case .stress: "stress"
        }
    }

    /// One-line meaning for a list row: "More sleep, less head pain."
    static func shortMeaning(for link: PatternLink) -> String {
        let direction = link.strength > 0 ? "more" : "less"
        return "More \(noun(link.a)), \(direction) \(noun(link.b))"
    }

    static func format(_ value: Double, for category: SignalCategory) -> String {
        category == .sleep
            ? String(format: "%.1fh", value)
            : String(format: "%.1f", value)
    }

    /// Splits the logged days by the first signal and reports what the second one
    /// did in each half. This is the comparison people actually understand — a
    /// correlation coefficient means nothing until it's expressed as two numbers.
    static func comparison(for link: PatternLink, logs: [DayLog]) -> ArmComparison? {
        var pairs: [(driver: Double, outcome: Double)] = []
        for log in logs {
            guard let d = log.reading(for: link.a), let o = log.reading(for: link.b) else { continue }
            pairs.append((d.value, o.value))
        }
        guard pairs.count >= 4 else { return nil }

        let sorted = pairs.map(\.driver).sorted()
        let median = sorted.count % 2 == 0
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]

        let high = pairs.filter { $0.driver >= median }
        let low = pairs.filter { $0.driver < median }
        guard high.count >= 2, low.count >= 2 else { return nil }

        let highAvg = high.map(\.outcome).reduce(0, +) / Double(high.count)
        let lowAvg = low.map(\.outcome).reduce(0, +) / Double(low.count)
        let cut = format(median, for: link.a)

        return ArmComparison(
            driver: link.a,
            outcome: link.b,
            highLabel: "\(cut) or more",
            lowLabel: "Under \(cut)",
            highAverage: highAvg,
            lowAverage: lowAvg,
            highDays: high.count,
            lowDays: low.count
        )
    }

    /// The headline sentence: two real numbers from her own days.
    static func readout(for link: PatternLink, comparison arm: ArmComparison) -> String {
        let outcomeNoun = noun(link.b)
        let high = format(arm.highAverage, for: link.b)
        let low = format(arm.lowAverage, for: link.b)
        let verb = arm.difference > 0 ? "higher" : "lower"
        var sentence = "On your \(arm.highLabel.lowercased()) \(noun(link.a)) days, \(outcomeNoun) averaged \(high) — against \(low) on the rest."
        if let percent = arm.percentDifference, percent >= 8 {
            sentence += " That's about \(Int(percent.rounded()))% \(verb)."
        }
        return sentence
    }

    static func confidence(for link: PatternLink) -> PatternConfidence {
        if link.sampleSize >= 14 && link.magnitude >= 0.5 { return .consistent }
        if link.sampleSize >= 10 || link.magnitude >= 0.55 { return .watching }
        return .early
    }

    /// What would move this connection up a confidence level.
    static func nextStep(for link: PatternLink) -> String {
        let confidence = confidence(for: link)
        switch confidence {
        case .consistent:
            return "This one has earned its place. Keep logging and Vida will tell you if it changes."
        case .watching:
            let needed = max(0, 14 - link.sampleSize)
            return needed > 0
                ? "About \(needed) more day\(needed == 1 ? "" : "s") logging both would make this a consistent finding."
                : "A little more strength in the data would make this a consistent finding."
        case .early:
            let needed = max(0, 10 - link.sampleSize)
            return needed > 0
                ? "Log both on about \(needed) more day\(needed == 1 ? "" : "s") before leaning on this."
                : "Keep logging both — strength, not just days, is what's missing here."
        }
    }

    /// The Lab experiment that would actually test this pair, if one exists.
    static func experiment(for link: PatternLink) -> ExperimentTemplate? {
        ExperimentTemplate.all.first {
            ($0.driver == link.a && $0.outcome == link.b) || ($0.driver == link.b && $0.outcome == link.a)
        }
    }

    static func explanation(for link: PatternLink) -> PatternExplanation {
        library[key(link.a, link.b)] ?? fallback(for: link)
    }

    private static func key(_ a: SignalCategory, _ b: SignalCategory) -> String {
        [a.rawValue, b.rawValue].sorted().joined(separator: "|")
    }

    /// Honest, non-specific explanation for pairs with no established mechanism.
    private static func fallback(for link: PatternLink) -> PatternExplanation {
        let direction = link.strength > 0 ? "rise and fall together" : "move in opposite directions"
        return PatternExplanation(
            mechanism: "In your logs, \(link.a.title.lowercased()) and \(link.b.title.lowercased()) \(direction). There are three honest explanations: one is nudging the other, the reverse is true, or something else — sleep, stress, illness, or where you are in your cycle — is moving both at once. A pattern in a personal log cannot tell these apart.",
            tries: [
                "Notice which one tends to change first. Order is a clue that correlation can't give you.",
                "Run a Lab experiment on this pair — that's designed to test direction rather than just spot it.",
                "If this is affecting your days, it's worth naming to a clinician. Doctor Prep will put it in their language."
            ],
            articleID: nil
        )
    }

    // MARK: - Mechanism library

    private static let library: [String: PatternExplanation] = [
        key(.sleep, .headache): .init(
            mechanism: "Short and broken sleep is one of the most reliably documented headache and migraine triggers there is. The leading explanation is that sleep is when the brain clears metabolic waste and resets pain-signalling thresholds. Cut that short and the threshold drops — the same everyday input that wouldn't normally register starts to hurt.",
            tries: [
                "Protect the wake time more than the bedtime. A steady wake time stabilises the whole rhythm faster.",
                "Note whether headaches show up on the morning after short sleep or the day after that — the lag is useful information.",
                "If headaches wake you from sleep rather than following it, that's worth mentioning to a clinician."
            ],
            articleID: "sleep-migraine"
        ),
        key(.sleep, .energy): .init(
            mechanism: "The obvious link, but the shape matters more than the total. Energy tracks sleep consistency at least as closely as sleep quantity — a steady seven hours usually beats a swinging five-then-ten. That's your circadian system being able to predict the day.",
            tries: [
                "Compare your most consistent week against your most erratic one rather than your longest against your shortest.",
                "If energy stays low after several good nights, that's a genuinely different question — worth raising with a clinician.",
                "Morning light within an hour of waking is the strongest lever on the timing system."
            ],
            articleID: "luteal-energy"
        ),
        key(.sleep, .mood): .init(
            mechanism: "Sleep loss reduces the prefrontal cortex's ability to regulate the amygdala — the emotional alarm system. The practical effect is that the same events land harder and recover slower. This is one of the best-established findings in sleep science, and it runs in both directions.",
            tries: [
                "On a low-mood day after poor sleep, treat the mood as provisional information rather than the truth about your life.",
                "Watch whether low mood is costing you sleep as well — that loop is common and worth naming.",
                "If low mood persists through well-slept weeks, it deserves separate attention."
            ],
            articleID: "pmdd-anxiety"
        ),
        key(.sleep, .focus): .init(
            mechanism: "Attention and working memory are among the first things to degrade when sleep is short, and among the last to recover. Notably, your sense of how impaired you are recovers faster than the impairment itself — which is why short sleep feels survivable while performance is still down.",
            tries: [
                "Schedule anything demanding for after your better nights if you have the choice.",
                "Treat a foggy day after short sleep as expected, not as evidence about your ability.",
                "Cut caffeine after early afternoon if it's eating into the nights."
            ],
            articleID: nil
        ),
        key(.sleep, .pain): .init(
            mechanism: "Poor sleep lowers pain thresholds measurably — the effect is large enough to see in lab studies after a single bad night. Pain then makes sleep harder, and the loop tightens. Evidence suggests sleep predicts next-day pain more strongly than pain predicts next-night sleep, which makes sleep the more useful lever.",
            tries: [
                "Pick the sleep side of the loop first — it tends to be the one you can actually move.",
                "Log whether the pain is what's waking you or what's keeping you from settling. They lead different places.",
                "Persistent pain that disrupts sleep most nights is a clear reason to see someone."
            ],
            articleID: "pain-science"
        ),
        key(.stress, .digestion): .init(
            mechanism: "The gut has its own nervous system, wired directly to the brain through the vagus nerve. Under stress the body diverts resources away from digestion, alters gut motility, and changes how sensitive the gut wall is to ordinary sensation. This is why stress can produce real, physical gut symptoms without any disease being present.",
            tries: [
                "Notice whether symptoms cluster around specific pressures — exams, conflict, travel — rather than specific foods.",
                "Slow exhales lengthen vagal tone, which is the direct line between the two systems.",
                "Blood in stool, unexplained weight loss, or night-time waking are not stress patterns. Those need a clinician."
            ],
            articleID: "gut-brain"
        ),
        key(.stress, .mood): .init(
            mechanism: "Sustained stress keeps cortisol elevated, and chronic elevation narrows emotional range — less capacity for pleasure, quicker irritability, slower recovery from setbacks. This is a physiological consequence of load, not a character trait or a failure of coping.",
            tries: [
                "Look for what's structurally heavy rather than what you're doing wrong. Load is usually the honest answer.",
                "Recovery needs to be scheduled with the same seriousness as the demands are.",
                "If mood stays low even when the pressure lifts, that's worth exploring with someone."
            ],
            articleID: "pmdd-anxiety"
        ),
        key(.stress, .headache): .init(
            mechanism: "Stress is the most commonly reported headache trigger in survey after survey. Two mechanisms are likely running at once: sustained muscle tension through the neck, jaw and scalp, and stress-driven changes in pain sensitivity. The let-down headache — arriving after the pressure ends rather than during it — is a well-documented variant.",
            tries: [
                "Check whether yours arrive during the pressure or in the calm afterwards. Let-down headaches are real and often missed.",
                "Jaw clenching and screen posture are quiet contributors worth ruling in or out.",
                "A sudden, severe, unfamiliar headache is never a stress pattern — that's an urgent call."
            ],
            articleID: "sleep-migraine"
        ),
        key(.sleep, .stress): .init(
            mechanism: "This runs both ways, and usually at once. Stress delays sleep onset and fragments sleep architecture; short sleep then raises next-day cortisol and lowers the threshold at which something feels overwhelming. Each night of the loop makes the next day slightly harder to meet.",
            tries: [
                "Break the loop at the point that's most under your control this week — usually the wind-down, not the worry itself.",
                "Writing tomorrow's worries down before bed has decent evidence behind it, and costs nothing.",
                "If you can't fall asleep because your mind won't stop most nights, say that out loud to someone."
            ],
            articleID: nil
        ),
        key(.stress, .skin): .init(
            mechanism: "Stress hormones raise sebum production and shift immune activity in the skin, which is why flares often follow high-pressure weeks. The delay is the tricky part — skin usually responds days after the stress, so the two rarely feel connected in the moment.",
            tries: [
                "Look for flares trailing stress by three to seven days rather than landing on the same day.",
                "Resist adding several new products during a flare — it makes the cause impossible to read.",
                "Painful, deep, scarring breakouts deserve medical treatment, not routine tweaks."
            ],
            articleID: nil
        ),
        key(.stress, .pain): .init(
            mechanism: "Pain is produced by the nervous system, not simply transmitted by it — and stress is one of the strongest modulators of how loudly that system speaks. Under load, the same tissue signal is amplified. The pain is entirely real; the volume is being set centrally.",
            tries: [
                "Treating stress as a pain input isn't dismissing the pain — it's using a lever that actually works.",
                "Gentle movement usually lowers the volume; total rest often raises it over time.",
                "New, severe, or one-sided pain should be assessed rather than managed at home."
            ],
            articleID: "pain-science"
        ),
        key(.movement, .energy): .init(
            mechanism: "Regular moderate movement improves mitochondrial density and cardiovascular efficiency, which raises baseline energy over weeks. The counterintuitive part is the timescale: a single hard session costs energy that day and pays it back later, so daily logs often show the benefit with a lag.",
            tries: [
                "Compare active weeks with quiet weeks rather than active days with quiet days.",
                "If movement reliably drains you for days afterwards, that's a signal worth investigating rather than pushing through.",
                "Walking counts. The evidence for moderate, frequent movement is stronger than for occasional intensity."
            ],
            articleID: "cycle-training"
        ),
        key(.movement, .mood): .init(
            mechanism: "The antidepressant effect of regular movement is one of the more robust findings in the field, with effect sizes comparable to some first-line treatments for mild to moderate low mood. Likely mechanisms include BDNF release, improved sleep, and reduced inflammatory signalling.",
            tries: [
                "Frequency beats intensity here. Short and often outperforms rare and heroic.",
                "Outdoors adds a measurable increment over the same movement indoors.",
                "Movement is a genuine treatment, not a substitute for one when things are serious."
            ],
            articleID: nil
        ),
        key(.movement, .sleep): .init(
            mechanism: "Movement increases slow-wave sleep — the physically restorative stage — and strengthens the circadian signal that tells your body when night is. Timing matters at the edges: vigorous exercise very late can delay sleep onset in some people, though far less universally than popular advice claims.",
            tries: [
                "Check whether late sessions actually cost you sleep in your own data before ruling them out.",
                "Morning movement outdoors does double duty: the movement and the light.",
                "Consistency in timing helps more than any specific hour."
            ],
            articleID: nil
        ),
        key(.nutrition, .energy): .init(
            mechanism: "Energy dips track blood sugar stability more closely than total calories. Meals with protein and fibre produce a gentler curve; fast carbohydrate alone produces a spike and a corresponding crash. Skipped meals show up in the afternoon, often blamed on the afternoon itself.",
            tries: [
                "Look at whether your crashes follow a particular meal or a missed one.",
                "Protein at breakfast has the largest effect on the rest of the day's curve.",
                "Persistent fatigue despite eating well is worth a blood test — iron deficiency is common and very treatable."
            ],
            articleID: "iron-fatigue"
        ),
        key(.nutrition, .mood): .init(
            mechanism: "Blood sugar swings and mood swings share machinery. A sharp glucose drop triggers adrenaline and cortisol release, which is physiologically close to anxiety — racing heart, irritability, shakiness. Irritability that arrives before a meal and lifts after one is a strong hint.",
            tries: [
                "Notice whether low mood lands before meals or after particular ones.",
                "Eating regularly matters more than eating perfectly.",
                "If mood is low regardless of how you're eating, the cause is somewhere else."
            ],
            articleID: "blood-sugar-mood"
        ),
        key(.nutrition, .headache): .init(
            mechanism: "Dehydration and skipped meals are two of the most common and most reversible headache triggers. Both act quickly — often within hours — which makes them relatively easy to confirm or rule out in your own data compared with slower triggers.",
            tries: [
                "Check the timing. Trigger headaches usually follow within hours, not days.",
                "Rule out the cheap explanations — water and food — before assuming something complicated.",
                "Caffeine withdrawal is a real and frequently missed headache cause."
            ],
            articleID: "sleep-migraine"
        ),
        key(.nutrition, .digestion): .init(
            mechanism: "Gut symptoms respond to what you eat, but also to when and how — meal spacing, speed, and portion size all affect motility. That's why the same food can be fine one day and not the next, and why food-by-food elimination so often fails to find a clean culprit.",
            tries: [
                "Track meal timing and size alongside content — the pattern often lives there.",
                "Avoid cutting out whole food groups without guidance. It rarely helps and can cost you nutrients.",
                "Persistent gut symptoms deserve a proper assessment rather than years of self-experiment."
            ],
            articleID: "gut-brain"
        ),
        key(.cycle, .pain): .init(
            mechanism: "Prostaglandins released as the uterine lining breaks down cause the muscle to contract — that's ordinary period pain. But pain severe enough to stop your day, pain outside of bleeding days, or pain that's worsening over time is not something to normalise. Endometriosis takes an average of seven to eight years to diagnose, largely because this pattern gets dismissed.",
            tries: [
                "Log severity honestly, including days you couldn't do things. That record is the strongest evidence you can bring a clinician.",
                "Pain that doesn't respond to over-the-counter anti-inflammatories is clinically meaningful information.",
                "Use Doctor Prep before an appointment. Severity plus impact plus duration is what gets taken seriously."
            ],
            articleID: "endo-pain"
        ),
        key(.cycle, .mood): .init(
            mechanism: "The late luteal phase brings a steep fall in progesterone and estrogen. Most people notice some shift; for a minority the response is severe and cyclical, which is what distinguishes PMDD from ordinary premenstrual change. The tell is timing — symptoms that lift within days of bleeding starting.",
            tries: [
                "Watch whether the lift comes reliably once bleeding starts. That timing is the diagnostic clue.",
                "Plan demanding commitments around the phase where you have room, if your life allows it.",
                "Cyclical mood changes that damage your relationships or work are treatable. That's worth saying out loud."
            ],
            articleID: "pmdd-anxiety"
        ),
        key(.cycle, .energy): .init(
            mechanism: "The hormonal drop before bleeding is a real metabolic event, not a mood. Body temperature, sleep quality and iron status all shift across the cycle, and heavy bleeding can push iron low enough to cause fatigue that persists well past the period itself.",
            tries: [
                "Expect the dip and plan for it rather than treating it as a personal failure.",
                "Heavy bleeding plus ongoing fatigue is a reason to have iron checked.",
                "Note which phase your best days fall in — that's useful for planning, not just for understanding."
            ],
            articleID: "luteal-energy"
        ),
        key(.cycle, .headache): .init(
            mechanism: "Menstrual migraine is triggered by the estrogen withdrawal just before bleeding starts, not by bleeding itself. These attacks tend to be longer, more resistant to treatment, and more likely to recur than other migraines — and they respond to different preventive strategies.",
            tries: [
                "Log the day relative to your period start. The estrogen-withdrawal window is what a clinician will ask about.",
                "Predictable timing means preventive treatment becomes possible — that's a real conversation to have.",
                "Migraine with aura matters for contraception choices. Mention it explicitly."
            ],
            articleID: "sleep-migraine"
        ),
        key(.cycle, .skin): .init(
            mechanism: "Androgen sensitivity rises in the luteal phase, increasing sebum production. Cyclical breakouts along the jaw and chin are the classic pattern. Skin responds on a slower clock than hormones do, so the flare usually lands after the hormonal shift rather than with it.",
            tries: [
                "Track breakouts by cycle day rather than by date — the pattern only appears that way.",
                "Judge any new routine over at least two full cycles before deciding it works.",
                "Cyclical acne responds well to specific medical treatments if it's affecting you."
            ],
            articleID: nil
        ),
        key(.cycle, .digestion): .init(
            mechanism: "The same prostaglandins that contract the uterus also act on the bowel, which is why digestion often shifts around bleeding days. Progesterone slows gut transit in the luteal phase, then that effect lifts — a common reason things swing from sluggish to loose across a single week.",
            tries: [
                "Log by cycle day so the pattern can separate itself from what you ate.",
                "Expect the swing rather than diagnosing yourself twice a month.",
                "Symptoms that persist across all phases are pointing somewhere other than your cycle."
            ],
            articleID: "gut-brain"
        ),
        key(.cycle, .focus): .init(
            mechanism: "Estrogen affects dopamine and acetylcholine signalling, both central to working memory and attention. Many people report clearer thinking mid-cycle and more effort required in the late luteal phase. The research is genuinely mixed on averages, which is exactly why your own pattern is worth more to you here than any study.",
            tries: [
                "Test it on yourself — Cycle Lab is built for this question.",
                "If the pattern holds, use it for scheduling rather than for judging yourself.",
                "Focus problems that ignore your cycle entirely are a separate question worth asking."
            ],
            articleID: "luteal-energy"
        ),
        key(.energy, .focus): .init(
            mechanism: "Sustained attention is metabolically expensive, so it degrades early when energy is low. This usually means both are downstream of something else — sleep, nutrition, illness, or iron status — rather than one causing the other.",
            tries: [
                "Look upstream. Check what sleep and nutrition were doing on those days.",
                "If both stay low for weeks regardless of rest, ask for bloods — iron and thyroid are the usual first checks.",
                "Match demanding work to your higher-energy windows where you can."
            ],
            articleID: "iron-fatigue"
        ),
        key(.mood, .focus): .init(
            mechanism: "Low mood consumes working memory. Rumination occupies the same limited resource that concentration needs, which is why difficulty focusing is a recognised symptom of low mood rather than a separate problem sitting next to it.",
            tries: [
                "Read a foggy day as information about load, not about capability.",
                "Externalise tasks onto paper when working memory is occupied — it genuinely helps.",
                "If both have been low for weeks, that pattern is worth bringing to someone."
            ],
            articleID: nil
        ),
        key(.mood, .pain): .init(
            mechanism: "Pain and mood share neural pathways and neurotransmitters — serotonin and norepinephrine are central to both. Living with pain lowers mood, and low mood measurably increases pain perception. Each one is a real, physical input to the other.",
            tries: [
                "Neither one is 'in your head'. They share hardware, which is a different claim entirely.",
                "Treating either side tends to help the other, so pick whichever is more movable.",
                "Chronic pain with persistent low mood deserves care for both, together."
            ],
            articleID: "pain-science"
        ),
        key(.digestion, .mood): .init(
            mechanism: "Roughly ninety percent of the body's serotonin is made in the gut, and signalling runs in both directions along the vagus nerve. Emerging research links gut microbiome composition to mood regulation, though the field is young and the causal direction is still genuinely unsettled.",
            tries: [
                "Watch which one tends to move first in your own logs — that's real evidence.",
                "Fibre variety has better evidence behind it than most probiotic supplements do.",
                "Don't over-restrict food to chase mood. That trade tends to go badly."
            ],
            articleID: "gut-brain"
        ),
        key(.focus, .headache): .init(
            mechanism: "Concentration difficulty is a recognised part of the migraine cycle, and it often begins in the prodrome — hours or even a day before pain arrives. That makes a foggy morning a potential early warning rather than an unrelated problem.",
            tries: [
                "Check whether fog reliably precedes your headaches. If it does, you've found a warning system.",
                "Early treatment in the prodrome works better than treatment once pain has established.",
                "Log the order of symptoms. Sequence is exactly what a clinician needs from you."
            ],
            articleID: "sleep-migraine"
        ),
        key(.skin, .digestion): .init(
            mechanism: "The gut-skin axis is an active research area: inflammatory signalling and barrier function in the gut appear to influence skin inflammation. The evidence is real but early, and far less settled than the internet's confidence about it suggests.",
            tries: [
                "Treat this as an open question in your own data rather than a rule you've read.",
                "Elimination diets for skin have a poor evidence base and a real nutritional cost.",
                "Persistent problems in both are worth a proper look rather than more experiments."
            ],
            articleID: nil
        )
    ]
}
