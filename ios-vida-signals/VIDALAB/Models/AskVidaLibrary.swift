import Foundation

/// A curated, evidence-based answer in Vida's knowledge library.
nonisolated struct VidaAnswer: Identifiable, Hashable {
    let id: String
    let question: String
    let shortAnswer: String
    let detail: [String]
    let articleID: String?
    let trackSuggestion: SignalCategory?
    let keywords: [String]
}

nonisolated enum AskVidaLibrary {
    static let answers: [VidaAnswer] = [
        .init(
            id: "period-exhaustion",
            question: "Why am I so exhausted during my period?",
            shortAnswer: "Three things overlap: a steep hormone drop, inflammatory signalling, and — if you bleed heavily — iron loss.",
            detail: [
                "Estrogen and progesterone both fall sharply right before bleeding starts. Estrogen supports serotonin and dopamine signalling, so its withdrawal alone can flatten drive and energy.",
                "As the uterine lining breaks down it releases prostaglandins. These cause cramping, but they're also inflammatory mediators, and inflammation produces the same fatigue and 'heavy' feeling you get with a mild illness.",
                "If your bleeding is heavy, you're also losing iron every cycle. Low iron stores cause fatigue and brain fog long before a standard blood count looks abnormal.",
                "A useful line for a doctor: 'I'm exhausted during my period every cycle and I'd like to discuss whether my iron stores should be checked.'"
            ],
            articleID: "iron-fatigue",
            trackSuggestion: .energy,
            keywords: ["tired", "exhausted", "fatigue", "period", "energy", "drained"]
        ),
        .init(
            id: "stomach-before-period",
            question: "Why does my stomach hurt before my period?",
            shortAnswer: "Prostaglandins released by the uterus act on the bowel sitting right next to it.",
            detail: [
                "As the uterine lining prepares to shed, it releases prostaglandins to make the uterus contract. Those molecules don't stay put — they act on nearby smooth muscle in the intestines.",
                "That's why period-time digestive changes are so common: cramping, looser stools, or the opposite in the luteal phase, when progesterone slows things down.",
                "Stress adds to it. The gut-brain axis means pressure and worry physically change motility and gut sensitivity.",
                "Pain with bowel movements specifically around your period is worth mentioning to a clinician — it's one of the symptom patterns associated with endometriosis."
            ],
            articleID: "gut-brain",
            trackSuggestion: .digestion,
            keywords: ["stomach", "gut", "digestion", "bloating", "nausea", "bowel", "cramps"]
        ),
        .init(
            id: "ovulation",
            question: "What's actually happening during ovulation?",
            shortAnswer: "A hormone surge releases an egg, and your body temperature shifts for the rest of the cycle.",
            detail: [
                "Through the follicular phase, follicles in the ovary mature and estrogen rises steadily. When estrogen crosses a threshold it flips the usual feedback loop and triggers a surge of luteinising hormone.",
                "That LH surge causes the dominant follicle to release an egg roughly 24–36 hours later. Some people feel this as a one-sided twinge — mittelschmerz.",
                "The follicle that's left behind becomes the corpus luteum and starts producing progesterone. Progesterone raises your core body temperature by about 0.3–0.5°C, and it stays raised until the next period.",
                "That temperature shift is why ovulation can only be confirmed after it's happened, not predicted precisely by a calendar."
            ],
            articleID: "luteal-energy",
            trackSuggestion: .cycle,
            keywords: ["ovulation", "ovulate", "egg", "mid cycle", "fertile", "lh"]
        ),
        .init(
            id: "premenstrual-anxiety",
            question: "Why does my anxiety get worse before my period?",
            shortAnswer: "Usually not abnormal hormones — an altered sensitivity to normal hormone changes.",
            detail: [
                "Studies comparing people with and without severe premenstrual mood symptoms generally find the same hormone levels in both groups. The difference is in how the brain responds to those changes.",
                "Progesterone's metabolite allopregnanolone normally calms the nervous system via GABA-A receptors. In some people those receptors adapt poorly to its rise and fall, and the effect flips to anxiety.",
                "Estrogen's fall matters too, because estrogen supports serotonin availability.",
                "The defining feature is timing: symptoms start in the luteal phase and lift within a few days of bleeding. Two to three cycles of dated tracking is the single most useful thing to bring to an appointment about it."
            ],
            articleID: "pmdd-anxiety",
            trackSuggestion: .mood,
            keywords: ["anxiety", "anxious", "pmdd", "pms", "mood", "depressed", "irritable", "crying"]
        ),
        .init(
            id: "endometriosis",
            question: "What does endometriosis actually do?",
            shortAnswer: "Tissue like the uterine lining grows outside the uterus, causing inflammation, scarring, and nerve sensitisation.",
            detail: [
                "The lesions respond to hormonal signals and bleed, but there's no way out. That drives chronic inflammation and, over time, adhesions and scar tissue.",
                "Lesions also recruit their own nerve supply and can sensitise surrounding nerves, so pain can persist between cycles and show up during bowel movements or sex.",
                "Diagnosis is commonly delayed by seven to ten years, largely because severe period pain gets normalised.",
                "Pain that keeps you home, doesn't respond to over-the-counter medication, or comes with bowel or bladder pain deserves proper evaluation."
            ],
            articleID: "endo-pain",
            trackSuggestion: .pain,
            keywords: ["endometriosis", "endo", "pelvic", "severe pain", "adhesions"]
        ),
        .init(
            id: "normal-vs-not",
            question: "What's normal period pain versus pain I should talk to a doctor about?",
            shortAnswer: "Pain that stops your life, doesn't respond to medication, or appears outside bleeding days is worth evaluating.",
            detail: [
                "Typical period pain is cramping in the first one to two days of bleeding, responds to over-the-counter anti-inflammatories, and lets you carry on with your day even if you'd rather not.",
                "Signals worth raising: pain that regularly makes you miss school or work; pain that doesn't respond to standard medication; pain that starts days before bleeding; pain during bowel movements, urination, or sex; and pain that's getting worse cycle by cycle.",
                "Heavy bleeding counts too — soaking through protection hourly, clots larger than a coin, or bleeding beyond seven days.",
                "None of these confirm a diagnosis. They're the pattern that justifies a proper look. Vida's Doctor Prep turns your logged data into exactly this kind of summary."
            ],
            articleID: "endo-pain",
            trackSuggestion: .pain,
            keywords: ["normal", "how bad", "doctor", "should i", "severe", "when to worry", "pain"]
        ),
        .init(
            id: "headaches-cycle",
            question: "Why do I get headaches around my period?",
            shortAnswer: "Estrogen withdrawal lowers your brain's threshold for a migraine attack.",
            detail: [
                "Menstrual migraine typically clusters from about two days before bleeding through day three — precisely the window where estrogen falls fastest.",
                "Estrogen modulates serotonin and CGRP, a neuropeptide central to migraine. When it drops, some of the brain's buffering against sensory overload drops with it.",
                "Triggers stack rather than act alone, so a short night of sleep during that window is much more likely to tip into head pain than the same short night mid-cycle.",
                "Logging both sleep and headaches for a few weeks usually makes your personal version of this pattern visible."
            ],
            articleID: "sleep-migraine",
            trackSuggestion: .headache,
            keywords: ["headache", "migraine", "head", "aura", "light sensitivity"]
        ),
        .init(
            id: "missing-period",
            question: "My period stopped and I'm training a lot. Is that okay?",
            shortAnswer: "No — it usually signals that energy intake isn't covering your training, and bone health is at stake.",
            detail: [
                "When available energy drops too low, the hypothalamus slows the hormone pulses that drive the reproductive cycle. Periods become irregular or stop.",
                "This is sometimes framed as convenient. It isn't. Low estrogen during the teen years affects bone density during the exact window when most of your peak bone mass is built.",
                "Performance, recovery, immune function, and mood all suffer alongside it.",
                "A period that disappears during heavy training warrants a medical assessment — not a shrug."
            ],
            articleID: "red-s",
            trackSuggestion: .movement,
            keywords: ["period stopped", "missing period", "amenorrhea", "training", "athlete", "no period"]
        ),
        .init(
            id: "brain-fog",
            question: "Why is my focus so bad some weeks?",
            shortAnswer: "Sleep, iron, glucose, and hormone shifts all affect the same cognitive machinery.",
            detail: [
                "Fragmented sleep is the biggest single contributor — working memory and attention are among the first things to degrade.",
                "Low iron stores impair oxygen delivery and dopamine synthesis, which shows up as fog well before a blood count looks abnormal.",
                "Blood glucose swings after skipped or carbohydrate-only meals trigger a stress-hormone response that competes directly with concentration.",
                "Estrogen supports prefrontal dopamine, so the low-estrogen days around your period can make effortful focus genuinely harder. Track focus alongside sleep and nutrition and your own driver usually becomes obvious."
            ],
            articleID: "iron-fatigue",
            trackSuggestion: .focus,
            keywords: ["focus", "concentration", "brain fog", "foggy", "memory", "distracted", "study"]
        ),
        .init(
            id: "acne-jaw",
            question: "Why do I break out along my jaw before my period?",
            shortAnswer: "Androgen activity is relatively higher in the late luteal phase, and jawline skin responds most.",
            detail: [
                "As estrogen and progesterone fall before bleeding, androgens like testosterone become relatively more influential. Androgens increase sebum production.",
                "Sebaceous glands along the jaw and lower face carry more androgen receptors, which is why premenstrual breakouts cluster there.",
                "Inflammation and stress hormones add to it — cortisol also stimulates sebum production.",
                "Breakouts that are severe, cystic, or paired with irregular cycles and excess hair growth are worth discussing, as that combination can point toward PCOS."
            ],
            articleID: "pcos-metabolic",
            trackSuggestion: .skin,
            keywords: ["acne", "skin", "breakout", "spots", "jaw", "pimples"]
        ),
        .init(
            id: "cramps-relief",
            question: "What actually helps with cramps?",
            shortAnswer: "Anti-inflammatories taken early, heat, and movement — all with real mechanisms behind them.",
            detail: [
                "Cramps are driven by prostaglandins. NSAIDs like ibuprofen work by blocking prostaglandin production, which is why taking them at the first sign rather than at peak pain works noticeably better.",
                "Heat is not a placebo — local heat above about 40°C activates heat receptors that inhibit pain signalling, and trials have found continuous heat comparable to ibuprofen for period pain.",
                "Gentle movement increases pelvic blood flow and triggers endogenous opioid release.",
                "If pain reliably breaks through appropriate doses of anti-inflammatories, that's a finding worth reporting to a clinician, not a reason to take more."
            ],
            articleID: "pain-science",
            trackSuggestion: .pain,
            keywords: ["cramps", "help", "relief", "ibuprofen", "heat", "what helps"]
        ),
        .init(
            id: "sleep-period",
            question: "Why can't I sleep well before my period?",
            shortAnswer: "Your core temperature is higher and your calming hormone is withdrawing.",
            detail: [
                "Falling asleep depends on your core body temperature dropping. After ovulation, progesterone raises it by 0.3–0.5°C and keeps it there, which makes that drop harder to achieve.",
                "Progesterone's calming metabolite allopregnanolone withdraws sharply in the last days before bleeding, which can fragment sleep and increase night waking.",
                "Cramps, headaches, and premenstrual anxiety all add mechanical interference on top.",
                "Cooling the room and protecting your sleep window specifically in that phase is a targeted intervention — and it's an excellent thing to run as a Sleep Lab experiment."
            ],
            articleID: "luteal-energy",
            trackSuggestion: .sleep,
            keywords: ["sleep", "insomnia", "can't sleep", "waking", "tired at night", "restless"]
        )
    ]

    /// Ranks library answers against a free-text question.
    static func bestMatch(for query: String) -> VidaAnswer? {
        let lower = query.lowercased()
        guard !lower.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let scored = answers.map { answer -> (VidaAnswer, Int) in
            var score = 0
            for keyword in answer.keywords where lower.contains(keyword) {
                score += keyword.count > 5 ? 3 : 2
            }
            for word in answer.question.lowercased().split(separator: " ") where word.count > 4 && lower.contains(word) {
                score += 1
            }
            return (answer, score)
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        return best.0
    }

    /// Like `bestMatch`, but only returns an answer Vida can actually cite.
    ///
    /// Every answer renders a "View sources" link built from its article's
    /// citations. If an answer has no resolvable article, there are no sources
    /// to show, so the answer doesn't get produced at all — an uncited claim
    /// about someone's body is exactly what this app exists not to do.
    static func citedMatch(for query: String) -> VidaAnswer? {
        guard let match = bestMatch(for: query) else { return nil }
        guard let articleID = match.articleID,
              let article = ScienceLibrary.article(id: articleID),
              !article.citations.isEmpty else { return nil }
        return match
    }

    static let suggested: [String] = [
        "Why am I so exhausted during my period?",
        "Why does my anxiety get worse before my period?",
        "What's normal period pain versus pain I should ask about?",
        "Why does my stomach hurt before my period?",
        "What's actually happening during ovulation?",
        "What actually helps with cramps?"
    ]
}
