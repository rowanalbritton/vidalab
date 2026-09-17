import Foundation

nonisolated struct ScienceArticle: Identifiable, Hashable {
    let id: String
    let pillar: Pillar
    let title: String
    let deck: String
    /// Short, plain-language body paragraphs.
    let body: [String]
    let takeaways: [String]
    let citations: [Citation]
    let relatedCategories: [SignalCategory]
    let readMinutes: Int
    let isPremium: Bool

    nonisolated enum Pillar: String, CaseIterable, Identifiable, Hashable {
        case cycle = "Cycle Health"
        case mind = "Mental Health"
        case nutrition = "Nutrition"
        case fitness = "Fitness"
        case pain = "Pain Science"
        case chronic = "Chronic Illness"
        case frontier = "New Science"
        case advocacy = "Being Heard"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .cycle: "moon.stars"
            case .mind: "brain.head.profile"
            case .nutrition: "leaf"
            case .fitness: "figure.run"
            case .pain: "waveform.path"
            case .chronic: "heart.text.square"
            case .frontier: "atom"
            case .advocacy: "hand.raised"
            }
        }
    }
}

nonisolated struct Citation: Hashable, Identifiable {
    var id: String { "\(authors)\(year)" }
    let authors: String
    let year: String
    let title: String
    let journal: String
}

nonisolated enum ScienceLibrary {
    static let articles: [ScienceArticle] = [
        .init(
            id: "luteal-energy",
            pillar: .cycle,
            title: "Why the week before your period drains you",
            deck: "The late luteal phase is a hormonal cliff — and your body spends real energy on it.",
            body: [
                "After ovulation, your body enters the luteal phase. Progesterone rises, peaks, and then — if no pregnancy occurs — falls sharply along with estrogen in the last few days before bleeding starts. That fall is not subtle. It is one of the steepest hormonal changes a healthy body goes through on a repeating basis.",
                "Progesterone has a sedating effect. It's metabolised into allopregnanolone, which acts on the same GABA receptors that anti-anxiety medications target. When progesterone is high you may feel heavy or flat; when it withdraws quickly, some people feel anxious, irritable, or wired-and-tired. Both are real physiology, not a character flaw.",
                "There's also a measurable metabolic cost. Resting metabolic rate tends to run modestly higher in the luteal phase, and core body temperature rises by roughly 0.3–0.5°C after ovulation. A warmer core makes deep sleep harder to hold, which stacks tiredness on top of tiredness.",
                "So a low-energy week before your period is not you being lazy. It is a hormonal withdrawal, a slightly higher energy burn, and often worse sleep — all at once."
            ],
            takeaways: [
                "The sharpest hormone drop of your cycle happens in the last 3–5 days before bleeding.",
                "Progesterone's metabolite acts on GABA receptors — the same system as anti-anxiety medication.",
                "Core temperature rises after ovulation, which can fragment deep sleep.",
                "Planning lighter demands into that window is a strategy, not a concession."
            ],
            citations: [
                .init(authors: "Baker, F. C., & Driver, H. S.", year: "2007", title: "Circadian rhythms, sleep, and the menstrual cycle", journal: "Sleep Medicine"),
                .init(authors: "Benton, M. J., et al.", year: "2020", title: "Effect of menstrual cycle on resting metabolism", journal: "PLOS ONE")
            ],
            relatedCategories: [.cycle, .energy, .sleep, .mood],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "sleep-migraine",
            pillar: .pain,
            title: "Sleep, hormones, and headache susceptibility",
            deck: "Two of the most reliable migraine triggers happen to interact with each other.",
            body: [
                "Migraine is not simply a bad headache. It's a disorder of how the brain regulates sensory input — a lowered threshold for becoming overwhelmed by light, sound, movement and internal signals. Anything that lowers that threshold makes an attack more likely.",
                "Short or fragmented sleep is one of the most consistently reported triggers. Sleep loss increases levels of CGRP, a neuropeptide central to migraine attacks, and reduces the brain's pain-inhibiting capacity. That's why an otherwise ordinary day can tip into head pain after a bad night.",
                "Estrogen withdrawal is another. Menstrual migraine is typically timed to the two days before bleeding through the first three days of flow — exactly when estrogen drops fastest. Estrogen modulates serotonin and CGRP signalling, so its withdrawal removes some of the brain's buffering.",
                "When both happen in the same window — a short night during the late luteal phase — the triggers stack. This is one of the most common patterns Vida finds in people who log both sleep and head pain."
            ],
            takeaways: [
                "Migraine is a threshold disorder: triggers stack rather than act alone.",
                "Sleep loss raises CGRP, a key migraine signalling molecule.",
                "Menstrual migraine clusters from 2 days before bleeding through day 3.",
                "Protecting sleep in the late luteal window is a targeted, testable strategy."
            ],
            citations: [
                .init(authors: "Vgontzas, A., & Pavlović, J. M.", year: "2018", title: "Sleep disorders and migraine", journal: "Headache"),
                .init(authors: "MacGregor, E. A.", year: "2020", title: "Menstrual and perimenopausal migraine", journal: "Maturitas")
            ],
            relatedCategories: [.sleep, .headache, .cycle],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "endo-pain",
            pillar: .pain,
            title: "What endometriosis actually does",
            deck: "It isn't 'bad cramps'. It's tissue, inflammation, and nerves — and it takes far too long to diagnose.",
            body: [
                "In endometriosis, tissue resembling the uterine lining grows outside the uterus — on the ovaries, the peritoneum, the bowel, sometimes further. That tissue responds to hormonal signals, bleeds, and has nowhere to go. The result is chronic inflammation, adhesions, and scarring.",
                "Two things make the pain distinctive. First, inflammatory mediators irritate local nerve endings directly. Second, lesions recruit their own nerve supply and can sensitise the surrounding nervous system, so pain begins to outlast the tissue events that started it. This is why endometriosis pain can occur outside of bleeding days, with bowel movements, or during sex.",
                "The average delay between first symptom and diagnosis is commonly reported at seven to ten years. A major reason is that severe period pain is normalised — by peers, by families, and sometimes by clinicians.",
                "Pain that reliably keeps you home from school, doesn't respond to over-the-counter medication, or comes with pain during bowel movements or sex deserves proper evaluation. That is not being dramatic. That is describing a symptom pattern accurately."
            ],
            takeaways: [
                "Endometriosis is tissue growth outside the uterus, not simply heavy cramping.",
                "Lesions recruit nerves and sensitise the nervous system, so pain can persist between cycles.",
                "Average diagnostic delay is widely reported as 7–10 years.",
                "Pain that stops your life is a clinical finding, not an exaggeration."
            ],
            citations: [
                .init(authors: "Zondervan, K. T., Becker, C. M., & Missmer, S. A.", year: "2020", title: "Endometriosis", journal: "New England Journal of Medicine"),
                .init(authors: "Agarwal, S. K., et al.", year: "2019", title: "Clinical diagnosis of endometriosis: a call to action", journal: "AJOG")
            ],
            relatedCategories: [.pain, .cycle, .digestion],
            readMinutes: 5,
            isPremium: false
        ),
        .init(
            id: "pmdd-anxiety",
            pillar: .mind,
            title: "Why anxiety can spike before your period",
            deck: "It isn't that your hormones are abnormal. It's how sensitive your brain is to normal changes.",
            body: [
                "One of the most useful findings in this area is counterintuitive: people with premenstrual mood symptoms usually have normal hormone levels. What differs is the brain's sensitivity to hormonal change.",
                "Allopregnanolone, a progesterone metabolite, normally calms the nervous system through GABA-A receptors. In some people those receptors don't adapt smoothly as allopregnanolone rises and falls, and the same molecule produces anxiety rather than calm. That's a receptor-level difference, not a willpower difference.",
                "Estrogen withdrawal matters too — estrogen supports serotonin availability, so its fall can flatten mood regulation in the same window.",
                "Symptoms that appear in the luteal phase and resolve within a few days of bleeding starting, cycle after cycle, are the defining pattern of premenstrual dysphoric disorder. Tracking that timing across two to three cycles is exactly what a clinician needs to evaluate it."
            ],
            takeaways: [
                "PMDD involves normal hormone levels and altered sensitivity to them.",
                "Allopregnanolone can be calming or anxiogenic depending on GABA-A receptor adaptation.",
                "The diagnostic signature is timing: luteal onset, resolution after bleeding starts.",
                "Two to three cycles of dated symptom data is the most useful thing you can bring to an appointment."
            ],
            citations: [
                .init(authors: "Schmidt, P. J., et al.", year: "2017", title: "Premenstrual dysphoric disorder symptoms following ovarian suppression", journal: "American Journal of Psychiatry"),
                .init(authors: "Bäckström, T., et al.", year: "2014", title: "Allopregnanolone and mood disorders", journal: "Progress in Neurobiology")
            ],
            relatedCategories: [.mood, .cycle, .stress],
            readMinutes: 5,
            isPremium: false
        ),
        .init(
            id: "iron-fatigue",
            pillar: .nutrition,
            title: "Heavy periods, iron, and the tiredness nobody checks",
            deck: "Ferritin can be low long before haemoglobin looks abnormal.",
            body: [
                "Iron deficiency is one of the most common nutritional deficiencies in menstruating teenagers, and heavy bleeding is a major driver. The symptoms — fatigue, breathlessness on stairs, brain fog, hair shedding, cold hands, restless legs — are easy to attribute to being busy.",
                "The important technical detail is that a standard blood count can look normal while iron stores are already depleted. Haemoglobin falls late. Ferritin, which reflects stored iron, falls first. If only a blood count is run, early deficiency can be missed entirely.",
                "Absorption matters as much as intake. Vitamin C alongside plant-based iron increases uptake; tea, coffee and calcium taken at the same meal reduce it.",
                "If you bleed through protection hourly, pass clots larger than a coin, or bleed longer than seven days, that's clinically heavy bleeding and worth raising alongside a request to discuss iron studies."
            ],
            takeaways: [
                "Ferritin drops before haemoglobin — a normal blood count doesn't rule out low iron.",
                "Heavy menstrual bleeding is a leading cause of iron deficiency in teens.",
                "Vitamin C boosts non-heme iron absorption; tea and coffee blunt it.",
                "Soaking through protection hourly or bleeding 7+ days counts as heavy."
            ],
            citations: [
                .init(authors: "Camaschella, C.", year: "2015", title: "Iron-deficiency anemia", journal: "New England Journal of Medicine"),
                .init(authors: "Munro, M. G., et al.", year: "2018", title: "Abnormal uterine bleeding and iron deficiency", journal: "Obstetrics & Gynecology")
            ],
            relatedCategories: [.nutrition, .energy, .cycle, .focus],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "red-s",
            pillar: .fitness,
            title: "When training stops your period",
            deck: "A missing period in an athlete is a signal of low energy availability, not a bonus.",
            body: [
                "Relative Energy Deficiency in Sport (RED-S) describes what happens when energy intake doesn't cover the cost of training plus the cost of simply being alive. The body responds by down-regulating the systems it considers optional in a famine — reproduction first.",
                "The reproductive shutdown is driven at the hypothalamus: GnRH pulses slow, LH and FSH fall, estrogen drops. Periods become irregular or stop. Because this is often framed as convenient, it can go unexamined for years.",
                "Low estrogen during adolescence is a serious skeletal issue. Roughly 90% of peak bone mass is laid down by the end of the teen years, and that window doesn't reopen. Athletes with amenorrhoea show measurably lower bone density and higher stress-fracture rates.",
                "Performance suffers too — reduced endurance, impaired recovery, more illness, and low mood. A period that disappears during heavy training is information, and it deserves a proper evaluation rather than a shrug."
            ],
            takeaways: [
                "Amenorrhoea in athletes usually reflects low energy availability, not fitness.",
                "The mechanism is hypothalamic suppression of reproductive hormones.",
                "~90% of peak bone mass is built during adolescence — the window is finite.",
                "Losing your period during training warrants medical assessment."
            ],
            citations: [
                .init(authors: "Mountjoy, M., et al.", year: "2023", title: "IOC consensus statement on REDs", journal: "British Journal of Sports Medicine"),
                .init(authors: "De Souza, M. J., et al.", year: "2014", title: "Female Athlete Triad Coalition consensus", journal: "BJSM")
            ],
            relatedCategories: [.movement, .cycle, .nutrition, .energy],
            readMinutes: 5,
            isPremium: false
        ),
        .init(
            id: "gut-brain",
            pillar: .mind,
            title: "Your gut and your stress share a wire",
            deck: "The vagus nerve carries far more traffic upward than down.",
            body: [
                "The gut and the brain are in constant two-way conversation through the vagus nerve, immune signalling, and microbial metabolites. Roughly 80% of vagal fibres are afferent — they carry information from the body up to the brain, not the other way round.",
                "Under stress, the hypothalamic-pituitary-adrenal axis alters gut motility, permeability, and sensitivity. This is why exam weeks reliably produce stomach symptoms in some people and why the pain is genuinely felt, not imagined.",
                "Visceral hypersensitivity is the key concept: the same amount of gas or stretch in the intestine produces more pain signalling in a sensitised system. The input hasn't changed; the amplification has.",
                "Cycle hormones add another layer. Prostaglandins released as the uterine lining breaks down act on nearby bowel smooth muscle, which is why period-time digestive changes are so common."
            ],
            takeaways: [
                "About 80% of vagus nerve traffic runs gut → brain.",
                "Stress physically changes gut motility and permeability.",
                "Visceral hypersensitivity means amplified signalling, not imagined pain.",
                "Prostaglandins explain period-related bowel changes."
            ],
            citations: [
                .init(authors: "Mayer, E. A., et al.", year: "2022", title: "The gut–brain axis", journal: "Annual Review of Medicine"),
                .init(authors: "Bharadwaj, S., et al.", year: "2015", title: "Menstrual cycle and gastrointestinal symptoms", journal: "Gastroenterology Report")
            ],
            relatedCategories: [.digestion, .stress, .cycle, .mood],
            readMinutes: 4,
            isPremium: true
        ),
        .init(
            id: "pain-science",
            pillar: .pain,
            title: "Pain is produced by your brain — and that's good news",
            deck: "Understanding the mechanism is one of the few things shown to reduce it.",
            body: [
                "Pain is not a direct readout of tissue damage. Nociceptors send danger signals; the brain weighs them against context, memory, expectation and threat, and then produces pain. That's why the same injury can hurt differently on different days.",
                "In persistent pain, the nervous system becomes better at producing the signal — a process called central sensitisation. Pain thresholds drop, the painful area can spread, and normally harmless sensations can hurt. The system has learned the pattern too well.",
                "This is not the same as 'it's in your head'. Sensitisation is a measurable neurological change. But because it is learned, it can also be unlearned — which is why graded activity, sleep, and reducing threat all measurably change pain.",
                "Pain neuroscience education itself has been shown in trials to reduce pain and disability. Understanding what's happening lowers the brain's threat assessment, and threat is one of the inputs."
            ],
            takeaways: [
                "Pain is an output of the brain, not a direct measure of damage.",
                "Central sensitisation makes the nervous system better at producing pain.",
                "Sensitisation is real, measurable, and modifiable.",
                "Learning the mechanism has itself been shown to reduce pain."
            ],
            citations: [
                .init(authors: "Moseley, G. L., & Butler, D. S.", year: "2015", title: "Fifteen years of explaining pain", journal: "Journal of Pain"),
                .init(authors: "Woolf, C. J.", year: "2011", title: "Central sensitization", journal: "Pain")
            ],
            relatedCategories: [.pain, .stress, .sleep],
            readMinutes: 5,
            isPremium: true
        ),
        .init(
            id: "cycle-training",
            pillar: .fitness,
            title: "Training across your cycle: what's actually established",
            deck: "The honest answer is more interesting than the confident one.",
            body: [
                "Cycle-based training plans are everywhere. The evidence behind them is thinner than the marketing suggests. The largest systematic review to date found that performance may be trivially reduced during the early follicular phase, with low certainty across studies.",
                "'Low certainty' matters. Many studies had small samples, didn't confirm ovulation with hormone testing, and defined phases inconsistently. That's a measurement problem, not proof of no effect.",
                "What is better established: core temperature rises after ovulation, which impairs heat tolerance; ACL injury risk appears elevated around ovulation when estrogen peaks and ligament laxity increases; and symptoms like cramping and poor sleep clearly affect how training feels.",
                "The practical conclusion is a scientific one — your own dated record of how sessions felt across several cycles is better evidence for you than a generic phase-based plan."
            ],
            takeaways: [
                "Population evidence for phase-based training is low-certainty.",
                "Post-ovulation core temperature rise impairs heat tolerance.",
                "ACL injury risk appears elevated around ovulation.",
                "Your own tracked data outranks a generic template."
            ],
            citations: [
                .init(authors: "McNulty, K. L., et al.", year: "2020", title: "Effects of menstrual cycle phase on exercise performance", journal: "Sports Medicine"),
                .init(authors: "Herzberg, S. D., et al.", year: "2017", title: "Menstrual cycle and ACL injury risk", journal: "Orthopaedic JSM")
            ],
            relatedCategories: [.movement, .cycle, .energy],
            readMinutes: 5,
            isPremium: true
        ),
        .init(
            id: "blood-sugar-mood",
            pillar: .nutrition,
            title: "Skipped meals, blood sugar, and mood",
            deck: "Your brain runs on a narrow fuel window and complains loudly when it narrows further.",
            body: [
                "The brain uses a disproportionate share of your daily glucose for its size. When blood glucose falls, the body releases adrenaline and cortisol to correct it — and those are the same molecules involved in anxiety and irritability.",
                "That's the mechanism behind feeling shaky, snappy, or tearful a few hours after a skipped or carbohydrate-only meal. It isn't moodiness; it's a counter-regulatory stress response.",
                "Protein and fibre slow gastric emptying and flatten the glucose curve, which is why the composition of a meal matters as much as its timing.",
                "The luteal phase adds another factor — insulin sensitivity decreases modestly after ovulation, so identical meals can produce larger glucose swings in the second half of your cycle."
            ],
            takeaways: [
                "Falling glucose triggers adrenaline and cortisol release.",
                "Irritability after skipped meals is a stress response, not a mood flaw.",
                "Protein and fibre flatten the glucose curve.",
                "Insulin sensitivity dips in the luteal phase."
            ],
            citations: [
                .init(authors: "Mergenthaler, P., et al.", year: "2013", title: "Sugar for the brain: glucose in brain function", journal: "Trends in Neurosciences"),
                .init(authors: "Yeung, E. H., et al.", year: "2010", title: "Insulin sensitivity across the menstrual cycle", journal: "JCEM")
            ],
            relatedCategories: [.nutrition, .mood, .energy, .cycle],
            readMinutes: 4,
            isPremium: true
        ),

        // MARK: - Chronic illness

        .init(
            id: "diagnostic-delay",
            pillar: .advocacy,
            title: "Why women wait years for a diagnosis",
            deck: "The delay is not bad luck. It is a measurable, documented pattern — and knowing its shape helps you work around it.",
            body: [
                "Across a range of conditions, women wait substantially longer than men for the same diagnosis. Endometriosis averages seven to eight years from first symptom. Autoimmune disease averages around four and a half years and several doctors. For conditions like POTS and ME/CFS, delays of five years or more are routine.",
                "There are structural reasons. Until 1993, women were not required to be included in US federally funded clinical trials, so a great deal of foundational medical knowledge was built on male bodies. Conditions that predominantly affect women remain comparatively under-researched and under-funded relative to how many people they affect and how much disability they cause.",
                "There is also a documented bias in how symptoms are interpreted. Studies of emergency departments have found women presenting with identical acute abdominal pain wait longer for analgesia and are less likely to receive opioid pain relief than men. Women's pain is more likely to be attributed to a psychological cause before physical causes have been excluded.",
                "None of this means your clinician is acting in bad faith. Most are working inside short appointments with incomplete information. But it does mean that walking in with specific, dated, quantified information is not being difficult — it is compensating for a known weakness in the system. Vague reports get vague responses. 'It hurts sometimes' invites reassurance. 'Pain at 7 or above on 14 of the last 30 days, clustered in the four days before bleeding, and I missed three days of work' invites investigation."
            ],
            takeaways: [
                "Endometriosis takes an average of 7–8 years to diagnose; autoimmune disease around 4.5.",
                "Women were not required in US clinical trials until 1993 — the knowledge base is genuinely incomplete.",
                "Studies show women wait longer for pain relief for identical presentations.",
                "Dated, quantified symptom records change the conversation more than any phrasing does."
            ],
            citations: [
                .init(authors: "Chen, E. H., et al.", year: "2008", title: "Gender disparity in analgesic treatment of emergency department patients with acute abdominal pain", journal: "Academic Emergency Medicine"),
                .init(authors: "Agarwal, S. K., et al.", year: "2019", title: "Clinical diagnosis of endometriosis: a call to action", journal: "American Journal of Obstetrics and Gynecology")
            ],
            relatedCategories: [.pain, .cycle, .energy, .mood],
            readMinutes: 5,
            isPremium: false
        ),
        .init(
            id: "inflammation-fatigue",
            pillar: .chronic,
            title: "Why inflammation makes you exhausted",
            deck: "Sickness behaviour is an ancient, coordinated program — and in chronic illness it never switches off.",
            body: [
                "When your immune system activates, it releases cytokines — signalling proteins including IL-6, IL-1β and TNF-α. These don't just fight pathogens. They cross into the brain and trigger what researchers call sickness behaviour: fatigue, social withdrawal, low mood, loss of appetite, and increased pain sensitivity.",
                "This is not a malfunction. It's an evolved strategy. An animal that rests and withdraws while fighting an infection survives better than one that carries on as normal. The exhaustion is the immune system's way of commandeering your energy budget.",
                "In chronic inflammatory conditions — autoimmune disease, inflammatory bowel disease, long COVID, and others — this program runs continuously at a low level. The result is fatigue that sleep does not fix, because it is not sleep debt. It's an active biological process consuming resources.",
                "This matters for how you interpret your own data. If your energy is low on days when other inflammatory markers are up — joint pain, gut symptoms, brain fog — that cluster is meaningful. It's not four separate problems. It may be one process with four faces."
            ],
            takeaways: [
                "Cytokines like IL-6 and TNF-α act directly on the brain to produce fatigue.",
                "Sickness behaviour is an evolved energy-conservation program, not weakness.",
                "Inflammatory fatigue does not resolve with more sleep, because it isn't sleep debt.",
                "Fatigue, pain, low mood and brain fog clustering together often means one underlying process."
            ],
            citations: [
                .init(authors: "Dantzer, R., et al.", year: "2008", title: "From inflammation to sickness and depression", journal: "Nature Reviews Neuroscience"),
                .init(authors: "Lacourt, T. E., et al.", year: "2018", title: "The high costs of low-grade inflammation: persistent fatigue as a consequence of reduced cellular-energy availability", journal: "Frontiers in Behavioral Neuroscience")
            ],
            relatedCategories: [.energy, .pain, .focus, .mood, .digestion],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "pacing-pem",
            pillar: .chronic,
            title: "Pacing, and why pushing through backfires",
            deck: "In post-exertional malaise, effort has a delayed price — which makes it almost impossible to learn from experience without data.",
            body: [
                "Post-exertional malaise (PEM) is the defining feature of ME/CFS and a common feature of long COVID. It means that physical, cognitive or emotional exertion produces a disproportionate worsening of symptoms — typically 12 to 72 hours later, and lasting days.",
                "That delay is the cruel part. Because the crash doesn't arrive during or immediately after the activity, the normal human process of learning cause and effect breaks down. You feel relatively fine on Saturday, do three things, and are flattened on Monday — by which point Monday feels like its own random event.",
                "This is also why the old advice of graded exercise — steadily increasing activity regardless of symptoms — was withdrawn from the UK's NICE guideline for ME/CFS in 2021 after evidence review. For a body with PEM, pushing through is not building tolerance. It is accumulating damage.",
                "Pacing is the alternative: staying within an energy envelope, resting before you need to rather than after, and breaking activity into intervals. Tracking helps enormously here, because it makes a two-day delay visible. A log that shows Saturday's movement score against Monday's energy score turns an invisible pattern into an obvious one."
            ],
            takeaways: [
                "PEM typically arrives 12–72 hours after exertion, which hides the cause.",
                "NICE withdrew graded exercise therapy for ME/CFS in 2021 following evidence review.",
                "Pacing means resting before exhaustion, not after it.",
                "Logging movement and energy on the same timeline is how a delayed crash becomes visible."
            ],
            citations: [
                .init(authors: "National Institute for Health and Care Excellence", year: "2021", title: "Myalgic encephalomyelitis/chronic fatigue syndrome: diagnosis and management (NG206)", journal: "NICE Guideline"),
                .init(authors: "Stussman, B., et al.", year: "2020", title: "Characterization of post-exertional malaise in patients with ME/CFS", journal: "Frontiers in Neurology")
            ],
            relatedCategories: [.energy, .movement, .focus, .pain, .sleep],
            readMinutes: 5,
            isPremium: false
        ),
        .init(
            id: "pots-autonomic",
            pillar: .chronic,
            title: "POTS: when standing up is the problem",
            deck: "A racing heart on standing isn't anxiety. It's an autonomic nervous system failing to compensate for gravity.",
            body: [
                "Postural orthostatic tachycardia syndrome is defined by a sustained heart rate increase of at least 30 beats per minute within ten minutes of standing (40 for adolescents), without a drop in blood pressure. It affects women far more than men, typically between 15 and 50.",
                "When you stand, gravity pulls roughly half a litre of blood into your legs and abdomen. A healthy autonomic system instantly constricts those vessels to push blood back up. In POTS that compensation is inadequate, so the heart compensates instead — beating faster to maintain output to the brain.",
                "The symptoms that follow — lightheadedness, palpitations, brain fog, nausea, shakiness, sudden fatigue — look a great deal like a panic attack. This is a major reason POTS is so often misdiagnosed as anxiety. The distinguishing question is what triggers it: POTS symptoms are provoked by position and duration upright, not by a psychological trigger.",
                "POTS has become far more visible since 2020, because it is one of the more common presentations of long COVID. That has driven real research attention to a condition that had been largely ignored."
            ],
            takeaways: [
                "Diagnostic threshold: +30 bpm within 10 minutes of standing, without a blood pressure drop.",
                "Symptoms overlap heavily with panic attacks, which drives misdiagnosis.",
                "The distinguishing feature is that posture and time upright trigger it.",
                "Long COVID has significantly increased research attention on POTS."
            ],
            citations: [
                .init(authors: "Vernino, S., et al.", year: "2021", title: "Postural orthostatic tachycardia syndrome (POTS): state of the science", journal: "Autonomic Neuroscience"),
                .init(authors: "Raj, S. R., et al.", year: "2022", title: "Long-COVID postural tachycardia syndrome: an American Autonomic Society statement", journal: "Clinical Autonomic Research")
            ],
            relatedCategories: [.energy, .focus, .headache, .movement],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "autoimmune-women",
            pillar: .chronic,
            title: "Why autoimmune disease targets women",
            deck: "Around 80% of autoimmune patients are women, and in 2024 researchers found a compelling explanation in the X chromosome.",
            body: [
                "Roughly four in five people with autoimmune disease are women. For lupus the ratio approaches nine to one. This has been observed for decades without a satisfying mechanistic explanation — hormones were assumed to be involved, but never explained the whole picture.",
                "In 2024, a Stanford team published work on Xist, a molecule that female cells use to silence one of their two X chromosomes. Xist forms large complexes with dozens of proteins, and those complexes appear to be strongly immunogenic — they generate autoantibodies. When researchers engineered male mice to produce Xist, those mice developed markedly more autoimmunity.",
                "This doesn't mean having two X chromosomes causes autoimmune disease. It means one long-standing epidemiological mystery now has a plausible molecular mechanism, which is how treatment targets eventually get found.",
                "Practically, autoimmune conditions are relapsing and remitting — they flare and settle. That makes them extremely hard to describe in a fifteen-minute appointment that happens to fall on a good day. A record of how many bad days there were, and what clustered with them, is often the most useful thing you can bring."
            ],
            takeaways: [
                "About 80% of autoimmune patients are women; lupus approaches a 9:1 ratio.",
                "Xist, the X-silencing molecule, forms complexes that provoke autoantibodies (Stanford, 2024).",
                "Flares are episodic, so a single appointment rarely captures the real picture.",
                "Counting bad days across months is more informative than describing today."
            ],
            citations: [
                .init(authors: "Dou, D. R., et al.", year: "2024", title: "Xist ribonucleoproteins promote female sex-biased autoimmunity", journal: "Cell"),
                .init(authors: "Angum, F., et al.", year: "2020", title: "The prevalence of autoimmune disorders in women: a narrative review", journal: "Cureus")
            ],
            relatedCategories: [.pain, .energy, .skin, .focus],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "sleep-pain-loop",
            pillar: .pain,
            title: "The sleep-pain loop runs one way more than the other",
            deck: "Pain disturbs sleep. But poor sleep predicts next-day pain more strongly than pain predicts poor sleep.",
            body: [
                "It is obvious that pain keeps you awake. What is less obvious, and better supported by the evidence, is the reverse direction — and it turns out to be the stronger one. Longitudinal studies that measure both night after night consistently find that a poor night predicts a higher-pain day more reliably than a high-pain day predicts a poor night.",
                "The mechanism is descending inhibition. Your brain actively suppresses a portion of the pain signals arriving from your body, using pathways that rely on serotonin and noradrenaline. Sleep deprivation measurably weakens this system. Experimental studies show that depriving healthy volunteers of sleep lowers their pain thresholds within a night or two.",
                "Deep slow-wave sleep appears to matter most. This is also where fibromyalgia research has focused for years, since disrupted slow-wave sleep is a consistent finding in that population.",
                "The practical implication is that sleep is not merely a comfort measure when you live with pain. It is one of the few levers that acts directly on your pain-inhibition machinery — and because the effect runs strongest from sleep to pain, it is a lever worth testing deliberately rather than assuming."
            ],
            takeaways: [
                "Poor sleep predicts next-day pain more strongly than pain predicts poor sleep.",
                "Sleep loss weakens descending inhibition — the brain's own pain suppression.",
                "Slow-wave sleep appears to be the critical stage.",
                "This makes sleep a genuine treatment lever, not just comfort."
            ],
            citations: [
                .init(authors: "Finan, P. H., Goodin, B. R., & Smith, M. T.", year: "2013", title: "The association of sleep and pain: an update and a path forward", journal: "The Journal of Pain"),
                .init(authors: "Krause, A. J., et al.", year: "2019", title: "The pain of sleep loss: a brain characterization in humans", journal: "Journal of Neuroscience")
            ],
            relatedCategories: [.sleep, .pain, .headache, .energy],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "heavy-bleeding",
            pillar: .cycle,
            title: "How heavy is too heavy?",
            deck: "Most people have no reference point for normal, so genuinely abnormal bleeding goes unreported for years.",
            body: [
                "Heavy menstrual bleeding has a clinical definition: blood loss that interferes with physical, social, emotional or material quality of life. The older research threshold was more than 80ml per cycle, but nobody measures that, so practical markers matter more.",
                "Signs worth reporting: soaking through a pad or tampon every hour for several consecutive hours, needing double protection, bleeding through to clothes or bedding regularly, passing clots larger than a 10p coin or a quarter, bleeding longer than seven days, or needing to plan your life around your period.",
                "This matters because heavy bleeding is both a symptom and a cause. It can point to fibroids, adenomyosis, polyps, a bleeding disorder such as von Willebrand disease, or thyroid dysfunction. And it causes iron deficiency, which produces its own cascade of fatigue, breathlessness, hair loss and brain fog that is frequently attributed to stress instead.",
                "A specific detail: around 20% of women referred for heavy menstrual bleeding turn out to have an undiagnosed inherited bleeding disorder. If you have also had heavy nosebleeds, bruise easily, or bled heavily after dental work, that pattern is worth naming explicitly."
            ],
            takeaways: [
                "Clots larger than a 10p coin, hourly soaking, or bleeding past 7 days all warrant review.",
                "Heavy bleeding is a leading and frequently missed cause of iron deficiency.",
                "Roughly 20% of those referred for heavy bleeding have an inherited bleeding disorder.",
                "Easy bruising and heavy nosebleeds alongside heavy periods form a reportable pattern."
            ],
            citations: [
                .init(authors: "National Institute for Health and Care Excellence", year: "2021", title: "Heavy menstrual bleeding: assessment and management (NG88)", journal: "NICE Guideline"),
                .init(authors: "Shankar, M., et al.", year: "2004", title: "von Willebrand disease in women with menorrhagia: a systematic review", journal: "BJOG")
            ],
            relatedCategories: [.cycle, .energy, .pain],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "pcos-metabolic",
            pillar: .cycle,
            title: "PCOS is a metabolic condition wearing a gynaecological name",
            deck: "The ovaries are where it shows up. Insulin is usually where it starts.",
            body: [
                "Polycystic ovary syndrome is diagnosed on the Rotterdam criteria: two of three features — irregular ovulation, clinical or biochemical excess androgens, and polycystic ovarian morphology on ultrasound. The name is unhelpful, because the 'cysts' are actually immature follicles, and the core driver in most cases is metabolic.",
                "Insulin resistance is present in a majority of people with PCOS, including many with a normal BMI. Elevated insulin drives the ovaries to produce more androgens and lowers sex hormone binding globulin, which frees up more testosterone. That produces the visible features — irregular cycles, acne along the jaw, unwanted hair growth — while the metabolic process underneath goes unaddressed.",
                "This reframing matters clinically. PCOS carries elevated long-term risk of type 2 diabetes, cardiovascular disease and endometrial hyperplasia. It also carries substantially elevated rates of depression and anxiety — which are too often treated as a reaction to the cosmetic symptoms rather than as part of the condition.",
                "Practically, the signals worth tracking are broader than cycle alone: energy, mood, skin and how you respond to meals. Those often move together in PCOS, and seeing them move together is what makes the metabolic story legible."
            ],
            takeaways: [
                "Diagnosis needs two of three Rotterdam criteria — ultrasound alone is not enough.",
                "Insulin resistance is common even at a normal BMI.",
                "High insulin raises androgens, producing the visible symptoms.",
                "Depression and anxiety rates are elevated as part of the condition, not just a reaction to it."
            ],
            citations: [
                .init(authors: "Teede, H. J., et al.", year: "2023", title: "International evidence-based guideline for the assessment and management of PCOS", journal: "Human Reproduction"),
                .init(authors: "Cooney, L. G., et al.", year: "2017", title: "High prevalence of moderate and severe depressive and anxiety symptoms in PCOS: systematic review and meta-analysis", journal: "Human Reproduction")
            ],
            relatedCategories: [.cycle, .skin, .energy, .mood, .nutrition],
            readMinutes: 5,
            isPremium: false
        ),
        .init(
            id: "thyroid-women",
            pillar: .chronic,
            title: "The thyroid, and why it gets missed",
            deck: "A small gland with system-wide reach, and symptoms that look like everything else.",
            body: [
                "Your thyroid sets the metabolic rate of essentially every tissue you have. When it runs slow, the result is fatigue, cold intolerance, weight change, constipation, dry skin, hair thinning, low mood and slowed thinking. When it runs fast, you get palpitations, anxiety, heat intolerance, tremor and weight loss.",
                "Both lists are made almost entirely of symptoms that get attributed to stress, poor sleep, or being busy. This is a substantial part of why thyroid dysfunction is so often found late — and it disproportionately affects women, who are five to eight times more likely to develop thyroid disease.",
                "Hashimoto's thyroiditis is the most common cause of hypothyroidism in iodine-sufficient countries, and it is autoimmune. It also frequently travels with other autoimmune conditions, so a personal or family history of one raises the index of suspicion for another.",
                "Thyroid function interacts with the menstrual cycle in both directions: thyroid dysfunction can cause heavy, irregular or absent periods, and it is a recognised contributor to infertility. If your cycle changed and your energy changed at the same time, that combination is worth a specific mention."
            ],
            takeaways: [
                "Women are 5–8 times more likely than men to develop thyroid disease.",
                "Symptoms overlap almost entirely with stress and burnout, which delays testing.",
                "Hashimoto's is autoimmune and often co-occurs with other autoimmune conditions.",
                "Simultaneous cycle changes and energy changes are worth raising together."
            ],
            citations: [
                .init(authors: "Chaker, L., et al.", year: "2017", title: "Hypothyroidism", journal: "The Lancet"),
                .init(authors: "Krassas, G. E., Poppe, K., & Glinoer, D.", year: "2010", title: "Thyroid function and human reproductive health", journal: "Endocrine Reviews")
            ],
            relatedCategories: [.energy, .mood, .skin, .focus, .cycle],
            readMinutes: 4,
            isPremium: false
        ),

        // MARK: - New science

        .init(
            id: "cgrp-migraine",
            pillar: .frontier,
            title: "CGRP: the first migraine drugs designed for migraine",
            deck: "After decades of borrowing medications from other conditions, migraine got a treatment built from its own biology.",
            body: [
                "For most of modern medicine, migraine was treated with drugs invented for something else — beta blockers for blood pressure, antidepressants, anti-epileptics. They helped some people, at the cost of side effects that came from acting on systems that had nothing to do with the headache.",
                "Calcitonin gene-related peptide, or CGRP, changed that. It's a neuropeptide released during migraine attacks that dilates blood vessels and transmits pain signals in the trigeminal system. Infusing CGRP into someone with migraine can trigger an attack; levels rise during spontaneous attacks and fall when they resolve.",
                "That made CGRP a target rather than a marker. Two classes of drug followed: monoclonal antibodies given monthly or quarterly for prevention (erenumab, fremanezumab, galcanezumab, eptinezumab), and small-molecule 'gepants' taken orally for acute treatment or prevention (ubrogepant, rimegepant, atogepant).",
                "They are not a cure and they don't work for everyone — roughly half of patients in trials achieve a 50% reduction in monthly migraine days. But they represent something meaningful: migraine treated as the specific neurological disorder it is. If you have migraine and have only ever been offered older preventives, this class is worth asking about by name."
            ],
            takeaways: [
                "CGRP is a neuropeptide that can trigger migraine attacks when infused.",
                "Monoclonal antibodies (monthly or quarterly) are used for prevention.",
                "Gepants are oral drugs used acutely or preventively.",
                "About half of trial patients see monthly migraine days cut by 50% or more."
            ],
            citations: [
                .init(authors: "Edvinsson, L., et al.", year: "2018", title: "CGRP as the target of new migraine therapies", journal: "Nature Reviews Neurology"),
                .init(authors: "Charles, A., & Pozo-Rosich, P.", year: "2019", title: "Targeting calcitonin gene-related peptide: a new era in migraine therapy", journal: "The Lancet")
            ],
            relatedCategories: [.headache, .pain, .cycle, .sleep],
            readMinutes: 4,
            isPremium: false
        ),
        .init(
            id: "endo-research",
            pillar: .frontier,
            title: "What's actually new in endometriosis research",
            deck: "Non-invasive diagnosis, bacterial theories, and treatments that don't suppress your hormones.",
            body: [
                "Endometriosis research was underfunded for so long that the basics were still contested. That is finally changing, and several lines of work are worth knowing about.",
                "Diagnosis is the biggest prize. Laparoscopy — surgery — has been the gold standard, which is a large part of why diagnosis takes years. Work on non-invasive alternatives is active: menstrual blood analysis, microRNA signatures in blood, and improved imaging protocols. A saliva-based microRNA test has been evaluated in France with encouraging accuracy, though it is not yet a global standard.",
                "A 2023 Nagoya University study found Fusobacterium in the endometrium of around 64% of women with endometriosis versus under 10% of controls, and showed antibiotic treatment reduced lesion formation in mice. It is one study in one population and does not mean endometriosis is an infection — but a treatable contributing factor would be a significant finding.",
                "On treatment, the interesting direction is non-hormonal. Current medical management mostly works by suppressing the cycle, which many people cannot tolerate or don't want. Research into the neural and immune components of endometriosis pain — including why lesion size correlates so poorly with pain severity — is opening targets that don't require shutting down your hormones."
            ],
            takeaways: [
                "Non-invasive diagnostics (saliva microRNA, menstrual blood) are the most active research front.",
                "A 2023 study linked Fusobacterium to endometriosis in 64% of cases versus <10% of controls.",
                "Lesion size correlates poorly with pain — which is itself a clue about mechanism.",
                "Non-hormonal treatment targets are an explicit research priority."
            ],
            citations: [
                .init(authors: "Muraoka, A., et al.", year: "2023", title: "Fusobacterium infection facilitates the development of endometriosis", journal: "Science Translational Medicine"),
                .init(authors: "Bendifallah, S., et al.", year: "2023", title: "Salivary microRNA signature for diagnosis of endometriosis", journal: "Journal of Clinical Medicine")
            ],
            relatedCategories: [.pain, .cycle, .digestion, .energy],
            readMinutes: 5,
            isPremium: false
        ),
        .init(
            id: "long-covid-research",
            pillar: .frontier,
            title: "Long COVID and the post-viral illness it resembles",
            deck: "A mass event forced medicine to take post-viral illness seriously — with consequences well beyond COVID.",
            body: [
                "Long COVID affects women disproportionately, with most cohorts reporting roughly 60–80% of patients being female. The symptom profile — profound fatigue, post-exertional malaise, cognitive dysfunction, autonomic problems — overlaps substantially with ME/CFS, a condition that had been dismissed and under-researched for decades.",
                "Several mechanisms are under active investigation, and they are not mutually exclusive: persistence of viral antigen in tissue reservoirs; reactivation of latent Epstein-Barr virus; autoimmunity triggered by the infection; microclotting and endothelial dysfunction; and dysregulation of the vagus nerve and autonomic system.",
                "The most consequential effect may be indirect. Because long COVID arrived at scale and affected previously healthy people with documented infection dates, it has been much harder to dismiss as psychological. That has pulled funding and serious scientific attention toward post-viral illness generally — which is the best news ME/CFS patients have had in forty years.",
                "For tracking purposes, the single most useful thing is the exertion-to-symptom lag. If your worst days reliably follow your most active days by one to three days, that pattern is clinically meaningful and is exactly the kind of thing that a daily log makes visible and memory does not."
            ],
            takeaways: [
                "Most long COVID cohorts are 60–80% women.",
                "Leading mechanisms: viral persistence, EBV reactivation, autoimmunity, microclots, autonomic dysfunction.",
                "Symptom overlap with ME/CFS is substantial.",
                "A one-to-three-day lag between exertion and crash is a meaningful, trackable pattern."
            ],
            citations: [
                .init(authors: "Davis, H. E., et al.", year: "2023", title: "Long COVID: major findings, mechanisms and recommendations", journal: "Nature Reviews Microbiology"),
                .init(authors: "Klein, J., et al.", year: "2023", title: "Distinguishing features of Long COVID identified through immune profiling", journal: "Nature")
            ],
            relatedCategories: [.energy, .focus, .sleep, .headache, .movement],
            readMinutes: 5,
            isPremium: false
        ),
        .init(
            id: "microbiome-research",
            pillar: .frontier,
            title: "The estrobolome: your gut bacteria and your hormones",
            deck: "A subset of your gut bacteria decides how much estrogen you recirculate — which connects two systems nobody used to connect.",
            body: [
                "Estrogen is processed in the liver and sent to the gut for excretion. But certain gut bacteria produce an enzyme called β-glucuronidase, which reactivates that estrogen and allows it to be reabsorbed into circulation. The collection of genes responsible is known as the estrobolome.",
                "This means your gut microbiome has a measurable influence on your circulating estrogen levels. When the estrobolome is altered — by antibiotics, by diet, by dysbiosis — estrogen recirculation changes with it. This has been implicated in research on endometriosis, PCOS, and hormone-sensitive cancers.",
                "Endometriosis research has been particularly interested. Studies have found differences in gut microbial composition between women with and without endometriosis, and there is active work on whether that difference is a cause, a consequence, or both.",
                "Caution is warranted: this is an area where the science is genuinely promising and the supplement marketing has run far ahead of it. No probiotic has been shown to treat endometriosis or PCOS. What is established is that the gut-hormone connection is real and bidirectional — which is reason enough to take gut symptoms seriously in a hormonal condition rather than treating them as a separate complaint."
            ],
            takeaways: [
                "Gut bacteria producing β-glucuronidase reactivate estrogen for reabsorption.",
                "The estrobolome influences circulating estrogen levels.",
                "Microbiome differences are documented in endometriosis and PCOS.",
                "No probiotic has been shown to treat either — the marketing is ahead of the evidence."
            ],
            citations: [
                .init(authors: "Baker, J. M., Al-Nakkash, L., & Herbst-Kralovetz, M. M.", year: "2017", title: "Estrogen-gut microbiome axis: physiological and clinical implications", journal: "Maturitas"),
                .init(authors: "Salliss, M. E., et al.", year: "2021", title: "The role of gut and genital microbiota in endometriosis", journal: "Human Reproduction Update")
            ],
            relatedCategories: [.digestion, .cycle, .nutrition, .skin],
            readMinutes: 4,
            isPremium: true
        ),
        .init(
            id: "wearables-research",
            pillar: .frontier,
            title: "What your wearable can and can't tell you",
            deck: "Continuous physiological data is genuinely useful, and consistently oversold.",
            body: [
                "Wearables measure some things well. Heart rate is accurate at rest. Heart rate variability is a reasonable proxy for autonomic state. Skin temperature trends can identify ovulation retrospectively with decent reliability. Step counts are fine. Sleep duration is roughly right.",
                "They measure other things poorly. Consumer sleep staging — the light/deep/REM breakdown — agrees with polysomnography far less well than the confident graphs suggest, with stage-level accuracy often in the 50–70% range. 'Recovery' and 'readiness' scores are proprietary composites, not clinical measures, and different devices will confidently disagree about the same night.",
                "The genuine value is in trends, not absolute numbers. A resting heart rate five beats above your own baseline for three days means something. Whether your absolute HRV is 45 or 60 means very little on its own, because it varies enormously between individuals.",
                "For chronic illness specifically, the useful application is correlation: pairing objective data your body produced overnight with the subjective experience only you can report. Neither is sufficient alone. A wearable cannot tell you how much pain you were in, and your memory cannot tell you what your heart rate did at 4am."
            ],
            takeaways: [
                "Resting heart rate, HRV trends and temperature shifts are reasonably reliable.",
                "Consumer sleep staging agrees with lab polysomnography far less than it appears to.",
                "Readiness scores are proprietary composites, not clinical measurements.",
                "Deviations from your own baseline carry the signal — not absolute values."
            ],
            citations: [
                .init(authors: "Chinoy, E. D., et al.", year: "2021", title: "Performance of seven consumer sleep-tracking devices compared with polysomnography", journal: "Sleep"),
                .init(authors: "Natarajan, A., Pantelopoulos, A., et al.", year: "2020", title: "Heart rate variability with photoplethysmography in 8 million individuals", journal: "The Lancet Digital Health")
            ],
            relatedCategories: [.sleep, .energy, .movement, .cycle],
            readMinutes: 4,
            isPremium: true
        )
    ]

    static func article(id: String) -> ScienceArticle? {
        articles.first { $0.id == id }
    }

    static func articles(for category: SignalCategory) -> [ScienceArticle] {
        articles.filter { $0.relatedCategories.contains(category) }
    }

    /// Finds the best article explaining a discovered link.
    static func article(explaining link: PatternLink) -> ScienceArticle? {
        articles
            .map { article -> (ScienceArticle, Int) in
                var score = 0
                if article.relatedCategories.contains(link.a) { score += 1 }
                if article.relatedCategories.contains(link.b) { score += 1 }
                return (article, score)
            }
            .filter { $0.1 == 2 }
            .map(\.0)
            .first
    }
}
