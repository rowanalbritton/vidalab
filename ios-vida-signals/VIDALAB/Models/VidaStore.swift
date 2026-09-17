import Foundation
import SwiftUI

/// Central app state: logs, cycle, experiments, membership, and saved preps.
@Observable
final class VidaStore {
    var name: String = ""
    var hasOnboarded: Bool = false
    var isPlus: Bool = false
    /// What she told Vida about her body during orientation.
    var profile: HealthProfile = HealthProfile()
    /// Locally stored profile photo, as JPEG data.
    var avatarData: Data?
    /// Email she asked her weekly report to be sent to.
    var reportEmail: String = ""
    var weeklyReportEnabled: Bool = false
    var lastReportSent: Date?
    var appearance: VidaAppearance = .system
    var logs: [DayLog] = []
    var experiments: [Experiment] = []
    var preps: [DoctorPrep] = []
    var savedArticleIDs: Set<String> = []
    var askedCountToday: Int = 0
    /// Which plan the member chose, shown back to her in Settings.
    var planName: String = ""
    /// Full membership standing: status, source, dates and audit history.
    var entitlement: Entitlement = Entitlement()
    /// Start date of the most recent period the user reported.
    var lastPeriodStart: Date?
    var averageCycleLength: Int = 28
    /// Whether the member has connected Apple Health.
    var healthSyncEnabled: Bool = false
    var lastHealthSync: Date?

    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    // MARK: - Day access

    var today: Date { Calendar.current.startOfDay(for: .now) }

    func log(on date: Date) -> DayLog? {
        let day = Calendar.current.startOfDay(for: date)
        return logs.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    var todayLog: DayLog? { log(on: today) }

    var todayCategories: Set<SignalCategory> { todayLog?.loggedCategories ?? [] }

    /// Fraction of the check-in set logged today — drives the leaf fill.
    var todayCompletion: Double {
        Double(todayCategories.count) / Double(min(6, SignalCategory.checkInSet.count))
    }

    // MARK: - Morning and evening

    /// The half of the day Vida is currently asking about.
    var currentPeriod: CheckInPeriod { CheckInPeriod.current() }

    func hasCompleted(_ period: CheckInPeriod, on date: Date = .now) -> Bool {
        log(on: date)?.isComplete(period) ?? false
    }

    var completedPeriodsToday: Set<CheckInPeriod> {
        todayLog?.completedPeriods ?? []
    }

    /// Which check-in to offer next: the current half if it's still open,
    /// otherwise whichever half is missing.
    var nextPeriod: CheckInPeriod? {
        let done = completedPeriodsToday
        if !done.contains(currentPeriod) { return currentPeriod }
        return CheckInPeriod.allCases.first { !done.contains($0) }
    }

    /// Both halves of today, as a fraction — drives the home ring.
    var todayPeriodCompletion: Double {
        Double(completedPeriodsToday.count) / 2.0
    }

    /// The signals Vida asks about in a period, ordered so the ones her profile
    /// says matter most come first.
    func categories(for period: CheckInPeriod) -> [SignalCategory] {
        let available = period.categories
        let focus = profile.focusSignals.filter { available.contains($0) }
        let rest = available.filter { !focus.contains($0) }
        return focus + rest
    }

    /// How far back a check-in may be backdated.
    static let backdateWindowDays: Int = 30

    /// The earliest day a check-in can still be added to.
    var earliestBackdate: Date {
        Calendar.current.date(byAdding: .day, value: -Self.backdateWindowDays, to: today) ?? today
    }

    /// True when `date` is inside the editable window (not future, not older
    /// than 30 days).
    func canLog(on date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return day <= today && day >= earliestBackdate
    }

    func record(_ reading: SignalReading, on date: Date = .now) {
        var entry = reading
        if entry.source == nil { entry.source = .manual }
        let day = Calendar.current.startOfDay(for: date)
        // Stamped with the absolute instant and her timezone. The log stays
        // keyed to the local day she was living in, so flying across timezones
        // never reshuffles which day a symptom belongs to.
        if entry.recordedAt == nil { entry.stamp(on: day) }
        if let index = logs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            // A reading replaces one from the same period only. Morning and
            // evening are separate accounts of the day and must both survive.
            let existing = logs[index].readings.firstIndex {
                $0.category == entry.category && $0.period == entry.period
            }
            if let existing {
                logs[index].readings[existing] = entry
            } else {
                logs[index].readings.append(entry)
            }
        } else {
            logs.append(DayLog(date: day, readings: [entry]))
        }
        logs.sort { $0.date > $1.date }
        if entry.category == .cycle, entry.value >= 3 {
            updatePeriodStart(with: day)
        }
        save()
    }

    /// Writes the short morning check-in into today's log.
    ///
    /// Both readings go through `record`, so the morning entries replace only
    /// other morning entries — an evening account of the same day survives — and
    /// they are marked manual, which means a later Apple Health import can never
    /// overwrite what she typed herself.
    func logMorning(_ checkIn: MorningCheckIn, on date: Date = .now) {
        for reading in checkIn.readings {
            record(reading, on: date)
        }
    }

    /// Today's morning answers, so reopening the flow shows what she already said.
    /// Falls back to an imported sleep figure when Apple Health beat her to it.
    var todayMorningDraft: MorningCheckIn {
        let sleep = todayLog?.reading(for: .sleep, period: .morning)
        let energy = todayLog?.reading(for: .energy, period: .morning)
        return MorningCheckIn(
            sleepHours: sleep?.value ?? 7.5,
            quality: sleep.flatMap { SleepQuality.from(tags: $0.tags) } ?? .okay,
            outlook: energy.map { EnergyOutlook.nearest(to: $0.value) } ?? .some
        )
    }

    /// True when Apple Health supplied the night before she opened the app.
    var morningSleepCameFromHealth: Bool {
        todayLog?.reading(for: .sleep, period: .morning)?.isManual == false
    }

    /// Removes one reading and recomputes anything that depended on it.
    ///
    /// Patterns, cycle dates and experiment results are all derived from `logs`,
    /// so they recalculate on the next read. Cycle start is the one piece of
    /// cached state that has to be rebuilt explicitly.
    func deleteReading(_ reading: SignalReading, on date: Date) {
        let calendar = Calendar.current
        guard let index = logs.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) else { return }
        logs[index].readings.removeAll { $0.id == reading.id }
        if logs[index].readings.isEmpty {
            logs.remove(at: index)
        }
        recomputeLastPeriodStart()
        save()
    }

    /// Removes an entire day. Used by the day editor's "delete this check-in".
    func deleteDay(_ date: Date) {
        let calendar = Calendar.current
        logs.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
        recomputeLastPeriodStart()
        save()
    }

    /// How many insights would change if a given day were removed — shown in
    /// the delete confirmation so the consequence isn't a surprise.
    func dependentInsightCount(ifRemoving date: Date) -> Int {
        let calendar = Calendar.current
        let remaining = visibleLogs.filter { !calendar.isDate($0.date, inSameDayAs: date) }
        let after = PatternEngine.meaningfulLinks(in: remaining).count
        return max(0, meaningfulLinks.count - after)
    }

    /// Merges readings pulled from Apple Health. A reading the member typed
    /// herself is never overwritten — her own account of her body always wins.
    /// Returns how many readings were actually added.
    @discardableResult
    func mergeHealthReadings(_ incoming: [Date: [SignalReading]]) -> Int {
        let calendar = Calendar.current
        var added = 0

        for (day, readings) in incoming {
            let key = calendar.startOfDay(for: day)
            let index = logs.firstIndex { calendar.isDate($0.date, inSameDayAs: key) }

            if let index {
                for reading in readings {
                    if let existing = logs[index].readings.firstIndex(where: { $0.category == reading.category }) {
                        guard !logs[index].readings[existing].isManual else { continue }
                        logs[index].readings[existing] = reading
                        added += 1
                    } else {
                        logs[index].readings.append(reading)
                        added += 1
                    }
                }
            } else {
                logs.append(DayLog(date: key, readings: readings))
                added += readings.count
            }
        }

        logs.sort { $0.date > $1.date }
        recomputeLastPeriodStart()
        lastHealthSync = .now
        healthSyncEnabled = true
        save()
        return added
    }

    /// Marks Health as connected even when the first import found nothing.
    ///
    /// Someone can grant access today with an empty Health store and start
    /// wearing a ring tomorrow. Without this, the connection would look dead and
    /// the automatic refresh would never run.
    func markHealthConnected() {
        guard !healthSyncEnabled else { return }
        healthSyncEnabled = true
        save()
    }

    /// Removes everything Apple Health contributed, leaving manual entries intact.
    func disconnectHealth() {
        for index in logs.indices {
            logs[index].readings.removeAll { !$0.isManual }
        }
        logs.removeAll { $0.readings.isEmpty }
        healthSyncEnabled = false
        lastHealthSync = nil
        save()
    }

    /// How many readings currently come from Apple Health.
    var healthReadingCount: Int {
        logs.reduce(0) { $0 + $1.readings.filter { !$0.isManual }.count }
    }

    private func updatePeriodStart(with day: Date) {
        guard let current = lastPeriodStart else {
            lastPeriodStart = day
            return
        }
        let gap = Calendar.current.dateComponents([.day], from: current, to: day).day ?? 0
        if gap >= 15 {
            averageCycleLength = max(21, min(40, gap))
            lastPeriodStart = day
        } else if gap < 0 {
            lastPeriodStart = day
        }
    }

    // MARK: - Free tier allowances
    //
    // Vida Free is meant to be genuinely useful on its own. Members get a month of
    // history, several insights, two full experiments, five questions a day, and
    // one complete Doctor Prep before anything asks them to pay.

    static let freeHistoryDays: Int = 30
    static let freeInsightLimit: Int = 3
    static let freeAskLimit: Int = 5
    static let freeExperimentLimit: Int = 2
    static let freePrepLimit: Int = 1

    var historyWindowDays: Int { isPlus ? 400 : Self.freeHistoryDays }

    var visibleLogs: [DayLog] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -historyWindowDays, to: today) else { return logs }
        return logs.filter { $0.date >= cutoff }
    }

    // MARK: - Cycle

    var cycleDay: Int? {
        guard let start = lastPeriodStart else { return nil }
        let days = Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0
        guard days >= 0 else { return nil }
        return (days % averageCycleLength) + 1
    }

    var cyclePhase: String? {
        guard let day = cycleDay else { return nil }
        switch day {
        case 1...5: return "Menstrual"
        case 6..<(averageCycleLength / 2 - 1): return "Follicular"
        case (averageCycleLength / 2 - 1)...(averageCycleLength / 2 + 2): return "Ovulatory"
        default: return "Luteal"
        }
    }

    var daysUntilNextPeriod: Int? {
        guard let day = cycleDay else { return nil }
        return max(0, averageCycleLength - day + 1)
    }

    // MARK: - Patterns

    var links: [PatternLink] {
        PatternEngine.allLinks(in: visibleLogs)
    }

    var meaningfulLinks: [PatternLink] {
        links.filter(\.isMeaningful)
    }

    /// Free members see the three strongest connections; Vida+ sees them all.
    var visibleInsights: [PatternLink] {
        isPlus ? meaningfulLinks : Array(meaningfulLinks.prefix(Self.freeInsightLimit))
    }

    var hiddenInsightCount: Int {
        max(0, meaningfulLinks.count - visibleInsights.count)
    }

    var loggedDayCount: Int { logs.count }

    var streak: Int {
        var count = 0
        var cursor = today
        while logs.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: cursor) }) {
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    func recentValues(for category: SignalCategory, days: Int = 14) -> [(Date, Double)] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: today) else { return [] }
        return logs
            .filter { $0.date >= cutoff }
            .compactMap { log in log.reading(for: category).map { (log.date, $0.value) } }
            .sorted { $0.0 < $1.0 }
    }

    // MARK: - Experiments

    /// Free members can run two labs at a time. Ending one always frees a slot,
    /// so nobody is ever punished for trying something and changing their mind.
    var freeExperimentsRemaining: Int {
        max(0, Self.freeExperimentLimit - experiments.count)
    }

    var canStartExperiment: Bool { isPlus || freeExperimentsRemaining > 0 }

    func start(_ template: ExperimentTemplate) {
        let experiment = Experiment(
            templateID: template.id,
            title: template.labName,
            question: template.question,
            driver: template.driver,
            outcome: template.outcome,
            threshold: template.threshold,
            highArmLabel: template.highArmLabel,
            lowArmLabel: template.lowArmLabel,
            durationDays: template.durationDays,
            startDate: today
        )
        experiments.append(experiment)
        save()
    }

    func stop(_ experiment: Experiment) {
        experiments.removeAll { $0.id == experiment.id }
        save()
    }

    func daysElapsed(in experiment: Experiment) -> Int {
        let d = Calendar.current.dateComponents([.day], from: experiment.startDate, to: today).day ?? 0
        return max(0, min(experiment.durationDays, d + 1))
    }

    func isRunning(_ template: ExperimentTemplate) -> Bool {
        experiments.contains { $0.templateID == template.id }
    }

    func result(for experiment: Experiment) -> ExperimentResult {
        PatternEngine.result(for: experiment, logs: logs)
    }

    func days(in experiment: Experiment) -> [ExperimentDay] {
        PatternEngine.days(for: experiment, logs: logs, today: today)
    }

    /// True once both of an experiment's signals are logged for the given day.
    func isLogged(_ experiment: Experiment, on date: Date) -> Bool {
        guard let log = log(on: date) else { return false }
        return log.reading(for: experiment.driver) != nil && log.reading(for: experiment.outcome) != nil
    }

    /// Records both signals of an experiment for one day in a single step.
    func logExperiment(_ experiment: Experiment, driver: Double, outcome: Double, on date: Date) {
        record(SignalReading(category: experiment.driver, value: driver, source: .manual), on: date)
        record(SignalReading(category: experiment.outcome, value: outcome, source: .manual), on: date)
    }

    /// Days inside the window where at least one of the two signals is missing.
    func missingDays(in experiment: Experiment) -> [ExperimentDay] {
        days(in: experiment).filter { !$0.isComplete }
    }

    // MARK: - Saved articles

    func toggleSave(_ id: String) {
        if savedArticleIDs.contains(id) { savedArticleIDs.remove(id) } else { savedArticleIDs.insert(id) }
        save()
    }

    // MARK: - Cloud restore

    /// Folds a cloud copy back into local storage after a reinstall.
    ///
    /// Callers pass only rows that don't already exist locally, so this is
    /// purely additive — it cannot overwrite or delete anything she logged on
    /// this device. That ordering matters: someone reinstalling and logging
    /// today before the restore lands should never watch today's entry get
    /// replaced by an older cloud row.
    func absorbRestored(
        logs restoredLogs: [DayLog],
        experiments restoredExperiments: [Experiment],
        preps restoredPreps: [DoctorPrep],
        savedArticleIDs restoredArticles: Set<String>
    ) {
        guard !restoredLogs.isEmpty || !restoredExperiments.isEmpty
                || !restoredPreps.isEmpty || !restoredArticles.isEmpty else { return }

        logs.append(contentsOf: restoredLogs)
        logs.sort { $0.date > $1.date }
        experiments.append(contentsOf: restoredExperiments)
        preps.append(contentsOf: restoredPreps)
        preps.sort { $0.createdAt > $1.createdAt }
        savedArticleIDs.formUnion(restoredArticles)
        save()
    }

    // MARK: - Ask Vida quota

    var askLimit: Int { isPlus ? .max : Self.freeAskLimit }
    var askRemaining: Int { isPlus ? .max : max(0, askLimit - askedCountToday) }

    func consumeAsk() {
        guard !isPlus else { return }
        askedCountToday += 1
        save()
    }

    // MARK: - Doctor prep

    var canCreatePrep: Bool { isPlus || preps.count < Self.freePrepLimit }

    func save(_ prep: DoctorPrep) {
        preps.insert(prep, at: 0)
        save()
    }

    func deletePrep(_ prep: DoctorPrep) {
        preps.removeAll { $0.id == prep.id }
        save()
    }

    // MARK: - Demo data

    /// Seeds 9 weeks of plausible data so patterns are immediately explorable.
    func seedDemoData() {
        var generated: [DayLog] = []
        let calendar = Calendar.current
        var generator = SeededGenerator(seed: 20260917)
        let cycleLength = 28
        let periodOffset = 6

        for back in 0..<63 {
            guard let date = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
            let dayIndex = 62 - back
            let cycleDay = ((dayIndex + periodOffset) % cycleLength) + 1
            let isLuteal = cycleDay >= 22
            let isBleeding = cycleDay <= 4

            let sleepBase = 7.4 - (isLuteal ? 0.9 : 0.0)
            let sleep = clamp(sleepBase + generator.noise(1.1), 4.2, 9.4)
            let shortSleep = sleep < 7.0

            var headache = generator.noise(1.2) + 1.0
            if shortSleep { headache += 4.0 }
            if isLuteal || isBleeding { headache += 2.4 }

            var pain = generator.noise(1.0) + 1.0
            if isBleeding { pain += 5.5 }
            if isLuteal { pain += 2.0 }

            var energy = 6.6 + generator.noise(1.1)
            if isLuteal { energy -= 2.4 }
            if isBleeding { energy -= 1.8 }
            if shortSleep { energy -= 1.4 }

            var mood = 6.8 + generator.noise(1.2)
            if isLuteal { mood -= 2.2 }

            let stress = clamp(4.4 + generator.noise(1.6) + (dayIndex % 7 < 5 ? 1.2 : -1.0), 0, 10)
            let nutrition = clamp(6.4 + generator.noise(1.5) - (stress > 6 ? 1.3 : 0), 0, 10)
            var digestion = 7.0 + generator.noise(1.2) - (stress > 6 ? 2.2 : 0)
            if isBleeding { digestion -= 1.8 }

            var focus = 6.5 + generator.noise(1.2)
            if shortSleep { focus -= 2.0 }
            if isLuteal { focus -= 1.2 }

            let movement = clamp(5.5 + generator.noise(2.4) - (isBleeding ? 2.2 : 0), 0, 10)
            var skin = 7.0 + generator.noise(1.1)
            if isLuteal { skin -= 2.3 }

            headache = clamp(headache, 0, 10)
            pain = clamp(pain, 0, 10)
            energy = clamp(energy, 0, 10)
            mood = clamp(mood, 0, 10)
            digestion = clamp(digestion, 0, 10)
            focus = clamp(focus, 0, 10)
            skin = clamp(skin, 0, 10)

            let flow: Double = isBleeding ? (cycleDay <= 2 ? 8 : 5) : 0

            // Sample days are logged across both halves, the way a real member
            // would: the night's account in the morning, the day's in the evening.
            // Morning energy runs a little higher than the same day's evening
            // figure, because a day spends you.
            let morningEnergy = clamp(energy + 1.1, 0, 10)
            var readings: [SignalReading] = [
                .init(category: .sleep, value: (sleep * 10).rounded() / 10, period: .morning),
                .init(category: .energy, value: morningEnergy.rounded(), period: .morning),
                .init(category: .mood, value: clamp(mood + 0.4, 0, 10).rounded(), period: .morning),
                .init(category: .energy, value: energy.rounded(), period: .evening),
                .init(category: .mood, value: mood.rounded(), period: .evening),
                .init(category: .stress, value: stress.rounded(), period: .evening),
                .init(category: .nutrition, value: nutrition.rounded(), period: .evening),
                .init(category: .movement, value: movement.rounded(), period: .evening),
                .init(category: .focus, value: focus.rounded(), period: .evening),
                .init(category: .digestion, value: digestion.rounded(), period: .evening),
                .init(category: .skin, value: skin.rounded(), period: .evening),
                .init(category: .cycle, value: flow, period: .evening)
            ]
            if headache > 2 {
                readings.append(.init(category: .headache, value: headache.rounded(),
                                      tags: shortSleep ? ["Temples", "Light sensitivity"] : ["Forehead"],
                                      period: .evening))
            }
            if pain > 2 {
                readings.append(.init(category: .pain, value: pain.rounded(),
                                      tags: isBleeding ? ["Pelvis", "Cramping"] : ["Lower back", "Dull ache"],
                                      period: .evening))
            }
            generated.append(DayLog(date: date, readings: readings))
        }

        logs = generated.sorted { $0.date > $1.date }
        lastPeriodStart = calendar.date(byAdding: .day, value: -((62 + periodOffset) % cycleLength) - 0, to: today)
        if let start = lastPeriodStart, start > today {
            lastPeriodStart = calendar.date(byAdding: .day, value: -cycleLength, to: start)
        }
        recomputeLastPeriodStart()
        save()
    }

    private func recomputeLastPeriodStart() {
        let bleeding = logs
            .filter { ($0.reading(for: .cycle)?.value ?? 0) >= 3 }
            .map(\.date)
            .sorted()
        guard let latest = bleeding.last else { return }
        var start = latest
        for date in bleeding.reversed() {
            let gap = Calendar.current.dateComponents([.day], from: date, to: start).day ?? 0
            if gap <= 1 { start = date } else { break }
        }
        lastPeriodStart = start
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

    func resetEverything() {
        logs = []
        experiments = []
        preps = []
        savedArticleIDs = []
        lastPeriodStart = nil
        askedCountToday = 0
        healthSyncEnabled = false
        lastHealthSync = nil
        save()
    }

    /// Hard delete for account removal.
    ///
    /// Unlike `resetEverything`, which clears logged data but keeps her as a
    /// returning member, this erases the profile, the photo, the report address
    /// and the stored snapshot itself — nothing is left to reconstruct a person
    /// from. Entitlement history goes too; billing lives with Apple, not here.
    func deleteEverything() {
        logs = []
        experiments = []
        preps = []
        savedArticleIDs = []
        lastPeriodStart = nil
        averageCycleLength = 28
        askedCountToday = 0
        healthSyncEnabled = false
        lastHealthSync = nil
        profile = HealthProfile()
        avatarData = nil
        name = ""
        reportEmail = ""
        weeklyReportEnabled = false
        lastReportSent = nil
        planName = ""
        isPlus = false
        entitlement = Entitlement()
        hasOnboarded = false
        defaults.removeObject(forKey: "vida.snapshot.v1")
    }

    // MARK: - Weekly report

    /// Free members can read the current week; Vida+ can look back through the
    /// archive. The report itself is never paywalled — being able to see your
    /// own week is table stakes, not a premium feature.
    func weeklyReport(weeksAgo: Int = 0) -> WeeklyReport {
        WeeklyReportEngine.build(
            logs: logs,
            profile: profile,
            links: meaningfulLinks,
            experiments: experiments,
            name: name,
            weeksAgo: weeksAgo,
            today: today
        )
    }

    /// How many past weeks she can open.
    var reportHistoryWeeks: Int { isPlus ? 12 : 1 }

    func markReportSent() {
        lastReportSent = .now
        save()
    }

    // MARK: - Membership
    //
    // `isPlus` stays the single question the UI asks ("is this unlocked?") while
    // `entitlement` carries why. Keeping both in sync in one place means no
    // screen can accidentally read a stale tier.

    /// Records a state change and keeps `isPlus` truthful.
    ///
    /// Idempotent on `transactionID`: a webhook delivered twice, or out of
    /// order, must not double-apply or flip someone back to free.
    func applyEntitlement(
        status: EntitlementStatus,
        source: EntitlementSource,
        plan: String? = nil,
        expiresAt: Date? = nil,
        graceUntil: Date? = nil,
        transactionID: String? = nil,
        detail: String
    ) {
        if let transactionID, entitlement.appliedTransactionIDs.contains(transactionID) {
            return
        }

        entitlement.status = status
        entitlement.source = source
        if let plan {
            entitlement.planName = plan
            planName = plan
        }
        if let expiresAt { entitlement.expiresAt = expiresAt }
        entitlement.graceUntil = graceUntil
        if let transactionID {
            entitlement.appliedTransactionIDs.append(transactionID)
        }
        entitlement.lastVerified = .now
        entitlement.auditLog.append(
            EntitlementEvent(
                date: .now,
                status: status,
                source: source,
                transactionID: transactionID,
                detail: detail
            )
        )
        isPlus = entitlement.hasAccess
        if !isPlus { planName = "" }
        save()
    }

    /// Cancels renewal but keeps access to the end of the paid period.
    func cancelPlus() {
        let source = entitlement.source ?? .appStore
        let end = entitlement.expiresAt
            ?? Calendar.current.date(byAdding: .month, value: 1, to: .now)
        applyEntitlement(
            status: .cancelled,
            source: source,
            expiresAt: end,
            detail: "Cancelled renewal. Access retained until the period ends."
        )
    }

    /// Immediate loss of access without touching a single logged day.
    func revokePlus(reason: String = "Purchase refunded.") {
        let source = entitlement.source ?? .appStore
        applyEntitlement(status: .revoked, source: source, detail: reason)
    }

    /// Payment failed. Keep her in, show a banner, don't lock anything.
    func enterBillingGrace(days: Int = 16) {
        let source = entitlement.source ?? .appStore
        let until = Calendar.current.date(byAdding: .day, value: days, to: .now)
        applyEntitlement(
            status: .grace,
            source: source,
            graceUntil: until,
            detail: "Payment failed. Access continues during the grace period."
        )
    }

    /// Downgrades only after the paid period has genuinely elapsed.
    ///
    /// Called on launch and foreground. Data is never deleted here — losing a
    /// subscription must never look like losing your history.
    func refreshEntitlementIfNeeded() {
        guard let expiry = entitlement.expiresAt else {
            isPlus = entitlement.hasAccess
            return
        }
        let stillPaid = expiry > .now
        switch entitlement.status {
        case .cancelled where !stillPaid:
            applyEntitlement(
                status: .expired,
                source: entitlement.source ?? .appStore,
                detail: "Paid period ended. Downgraded to Vida Free; all data retained."
            )
        case .grace:
            if let grace = entitlement.graceUntil, grace < .now {
                applyEntitlement(
                    status: .expired,
                    source: entitlement.source ?? .appStore,
                    detail: "Grace period ended without a successful payment."
                )
            }
        default:
            isPlus = entitlement.hasAccess
        }
    }

    /// Applies what the store says, when the store actually said something.
    ///
    /// The `nil` case is the important one: a failed lookup, an offline
    /// launch, or a provider with no authority must leave the last known tier
    /// exactly as it was. Silently dropping someone to free because a network
    /// call timed out is the worst possible failure here.
    func reconcile(with snapshot: MembershipSnapshot?) {
        guard let snapshot else {
            isPlus = entitlement.hasAccess
            return
        }

        // The store having no record doesn't override a membership bought
        // somewhere this provider can't see (web, or a promo we granted).
        if snapshot.status == .free {
            if entitlement.source == .appStore, entitlement.hasAccess {
                applyEntitlement(
                    status: .expired,
                    source: .appStore,
                    transactionID: snapshot.transactionID,
                    detail: snapshot.changeDescription
                )
            } else {
                entitlement.lastVerified = .now
                isPlus = entitlement.hasAccess
                save()
            }
            return
        }

        // Nothing changed — record that we checked and move on, so the
        // audit log doesn't fill with identical lines on every foreground.
        if entitlement.status == snapshot.status,
           entitlement.expiresAt == snapshot.expiresAt {
            entitlement.lastVerified = .now
            isPlus = entitlement.hasAccess
            save()
            return
        }

        applyEntitlement(
            status: snapshot.status,
            source: .appStore,
            plan: snapshot.planName,
            expiresAt: snapshot.expiresAt,
            graceUntil: snapshot.graceUntil,
            transactionID: snapshot.transactionID,
            detail: snapshot.changeDescription
        )
    }

    /// True when she already pays, so a second surface can refuse politely
    /// instead of selling her the same thing twice.
    var alreadySubscribed: Bool {
        entitlement.hasAccess && entitlement.status != .free
    }

    /// Message for an attempted duplicate purchase.
    var duplicateSubscriptionMessage: String {
        let where_ = entitlement.source?.label ?? "another device"
        let manage = entitlement.source?.manageInstruction ?? ""
        return "You're already a Vida+ member, billed through \(where_). \(manage)"
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var name: String
        var hasOnboarded: Bool
        var isPlus: Bool
        var logs: [DayLog]
        var experiments: [Experiment]
        var preps: [DoctorPrep]
        var savedArticleIDs: [String]
        var lastPeriodStart: Date?
        var averageCycleLength: Int
        var askedCountToday: Int
        var askDate: Date
        var planName: String?
        var healthSyncEnabled: Bool?
        var lastHealthSync: Date?
        var profile: HealthProfile?
        var avatarData: Data?
        var reportEmail: String?
        var weeklyReportEnabled: Bool?
        var lastReportSent: Date?
        var appearance: String?
        /// Optional so snapshots written before membership tracking decode.
        var entitlement: Entitlement?
    }

    func save() {
        let snapshot = Snapshot(
            name: name, hasOnboarded: hasOnboarded, isPlus: isPlus, logs: logs,
            experiments: experiments, preps: preps, savedArticleIDs: Array(savedArticleIDs),
            lastPeriodStart: lastPeriodStart, averageCycleLength: averageCycleLength,
            askedCountToday: askedCountToday, askDate: today,
            planName: planName,
            healthSyncEnabled: healthSyncEnabled,
            lastHealthSync: lastHealthSync,
            profile: profile,
            avatarData: avatarData,
            reportEmail: reportEmail,
            weeklyReportEnabled: weeklyReportEnabled,
            lastReportSent: lastReportSent,
            appearance: appearance.rawValue,
            entitlement: entitlement
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: "vida.snapshot.v1")
    }

    private func load() {
        guard let data = defaults.data(forKey: "vida.snapshot.v1"),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        name = snapshot.name
        hasOnboarded = snapshot.hasOnboarded
        isPlus = snapshot.isPlus
        logs = snapshot.logs
        experiments = snapshot.experiments
        preps = snapshot.preps
        savedArticleIDs = Set(snapshot.savedArticleIDs)
        lastPeriodStart = snapshot.lastPeriodStart
        averageCycleLength = snapshot.averageCycleLength
        planName = snapshot.planName ?? ""
        healthSyncEnabled = snapshot.healthSyncEnabled ?? false
        lastHealthSync = snapshot.lastHealthSync
        profile = snapshot.profile ?? HealthProfile()
        avatarData = snapshot.avatarData
        reportEmail = snapshot.reportEmail ?? ""
        weeklyReportEnabled = snapshot.weeklyReportEnabled ?? false
        lastReportSent = snapshot.lastReportSent
        appearance = snapshot.appearance.flatMap { VidaAppearance(rawValue: $0) } ?? .system
        askedCountToday = Calendar.current.isDate(snapshot.askDate, inSameDayAs: today) ? snapshot.askedCountToday : 0

        // The locally cached tier is the source of truth at launch. If a
        // remote check later fails, a paying member keeps her access rather
        // than being silently demoted to free.
        if let stored = snapshot.entitlement {
            entitlement = stored
        } else if snapshot.isPlus {
            // Migrate a pre-entitlement member without interrupting her.
            entitlement = Entitlement(
                status: .active,
                source: .appStore,
                planName: snapshot.planName ?? "",
                lastVerified: nil
            )
        }
        refreshEntitlementIfNeeded()
    }
}

/// Deterministic noise so the demo data set is stable across launches.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 11) & 0xFFFFFFFF) / Double(0xFFFFFFFF)
    }

    /// Roughly centred noise in ±amplitude.
    mutating func noise(_ amplitude: Double) -> Double {
        ((next() + next() + next()) / 3.0 - 0.5) * 2.0 * amplitude
    }
}
