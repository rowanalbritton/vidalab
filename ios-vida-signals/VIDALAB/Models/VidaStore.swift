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
    /// Forest (dark) is the default look; Daylight and Automatic remain in Settings.
    var appearance: VidaAppearance = .dark
    var logs: [DayLog] = []
    var meals: [MealEntry] = []
    /// Deletions waiting to be pushed. Cleared once the server has them.
    private(set) var pendingDeletions: [DeletedReadingMarker] = []
    var experiments: [Experiment] = []
    var preps: [DoctorPrep] = []
    /// First day of the most recent month whose Lab Notes have been shown.
    /// Keyed by month rather than a bool so the recap arrives once each month
    /// and never twice.
    var lastLabNotesMonth: Date?
    /// Her diary, newest first. Kept on this device only.
    var diary: [DiaryEntry] = []
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

    /// When false the store neither loads nor writes the on-device snapshot.
    ///
    /// Exists so tests can exercise real store logic without reading — or,
    /// worse, overwriting — the snapshot belonging to whoever is signed in on
    /// the simulator.
    private let persistent: Bool
    /// Snapshots are private to the signed-in member. Keeping a single device-
    /// wide snapshot let a second account inherit the previous person's logs.
    private var activeAccountID: String?

    /// The diary is kept apart from the rest of the journal, in its own file
    /// under complete protection (see DiaryVault).
    @ObservationIgnored private let diaryVault: DiaryVault
    /// True when the diary file exists but the phone was locked when it was
    /// read. The diary is then never written, so it can't be overwritten with
    /// an empty list, until `reloadDiaryIfLocked()` opens it.
    @ObservationIgnored private(set) var diaryLocked = false
    /// A diary still waiting in an old snapshot while the vault is locked, so
    /// the next save doesn't drop it before it has been moved.
    @ObservationIgnored private var pendingLegacyDiary: [DiaryEntry]?

    init(persistent: Bool = true, diaryVault: DiaryVault = .standard) {
        self.persistent = persistent
        self.diaryVault = diaryVault
    }

    /// Selects the on-device journal that belongs to the current account.
    ///
    /// A signed-out app deliberately has no loaded journal. This prevents an
    /// account created on a shared device from ever seeing another person's
    /// local health entries before cloud sync has had a chance to run.
    func activateAccount(_ userID: String?) {
        guard activeAccountID != userID else { return }

        activeAccountID = userID
        resetInMemory()

        guard persistent, userID != nil else { return }
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

    /// The signals Vida asks about in a period, ordered so the ones the
    /// profile says matter most come first.
    ///
    /// The single place cycle gating takes effect for the check-in: every
    /// flow that asks a question routes through here.
    func categories(for period: CheckInPeriod) -> [SignalCategory] {
        let available = period.categories.filter(profile.includes)
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
        let day = logs[index].date
        logs[index].readings.removeAll { $0.id == reading.id }
        if logs[index].readings.isEmpty {
            logs.remove(at: index)
        }
        recordDeletion(of: [reading], on: day)
        recomputeLastPeriodStart()
        save()
    }

    /// Removes an entire day. Used by the day editor's "delete this check-in".
    func deleteDay(_ date: Date) {
        let calendar = Calendar.current
        // Captured before the removal — every reading in the day needs its own
        // tombstone, because the event stream is keyed per reading.
        if let doomed = logs.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            recordDeletion(of: doomed.readings, on: doomed.date)
        }
        logs.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
        recomputeLastPeriodStart()
        save()
    }

    /// Queues tombstones for readings the member removed on this device.
    ///
    /// Deliberately not called from the Apple Health reconciliation path: those
    /// readings are replaced by a fresh import moments later, and a tombstone
    /// there would delete the member's imported history on her other device.
    private func recordDeletion(of readings: [SignalReading], on date: Date) {
        let deletedAt = Date()
        for reading in readings {
            let marker = DeletedReadingMarker(
                date: date,
                category: reading.category,
                period: reading.period ?? .morning,
                deletedAt: deletedAt
            )
            // A re-deletion supersedes the earlier marker rather than queueing
            // a second one for the same key.
            pendingDeletions.removeAll {
                $0.date == marker.date && $0.category == marker.category && $0.period == marker.period
            }
            pendingDeletions.append(marker)
        }
    }

    /// Drops markers the sync service has confirmed the server accepted.
    func clearPendingDeletions(_ pushed: [DeletedReadingMarker]) {
        guard !pushed.isEmpty else { return }
        let settled = Set(pushed)
        pendingDeletions.removeAll { settled.contains($0) }
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
        // Screens read the links many times per render, and each pass compares
        // every pair of signals across the whole history. Recompute only when
        // the logs actually change.
        let logs = visibleLogs
        let key = logs.hashValue
        if let cached = linksCache, cached.key == key { return cached.links }
        let fresh = PatternEngine.allLinks(in: logs)
        linksCache = (key, fresh)
        return fresh
    }

    @ObservationIgnored private var linksCache: (key: Int, links: [PatternLink])?

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
        meals restoredMeals: [MealEntry] = [],
        experiments restoredExperiments: [Experiment],
        preps restoredPreps: [DoctorPrep],
        savedArticleIDs restoredArticles: Set<String>
    ) {
        guard !restoredLogs.isEmpty || !restoredMeals.isEmpty || !restoredExperiments.isEmpty
                || !restoredPreps.isEmpty || !restoredArticles.isEmpty else { return }

        logs.append(contentsOf: restoredLogs)
        logs.sort { $0.date > $1.date }
        meals.append(contentsOf: restoredMeals)
        meals.sort { $0.date > $1.date }
        experiments.append(contentsOf: restoredExperiments)
        preps.append(contentsOf: restoredPreps)
        preps.sort { $0.createdAt > $1.createdAt }
        savedArticleIDs.formUnion(restoredArticles)
        save()
    }

    /// Merges the encrypted per-reading stream pulled from another device.
    ///
    /// Readings have a stable key of local day, signal category, and period.
    /// The newest timestamp wins that key; equal timestamps intentionally keep
    /// this device's value, so a delayed response can never silently overwrite
    /// an edit the member just made here. A tombstone follows the same rule.
    @discardableResult
    func mergeSyncedCheckInReadings(_ incoming: [SyncedCheckInReading]) -> Int {
        var changes = 0
        let calendar = Calendar.current

        for event in incoming.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            let period = event.reading.period ?? .morning

            // A deletion made here but not yet pushed still outranks whatever
            // the server holds. Restore runs before push, so without this the
            // server's surviving copy would reinstate the reading the member
            // just deleted, moments before the tombstone went up.
            let supersededByLocalDeletion = pendingDeletions.contains { marker in
                calendar.isDate(marker.date, inSameDayAs: event.date)
                    && marker.category == event.reading.category
                    && marker.period == period
                    && marker.deletedAt >= event.updatedAt
            }
            if supersededByLocalDeletion { continue }

            if let logIndex = logs.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: event.date) }) {
                if let readingIndex = logs[logIndex].readings.firstIndex(where: {
                    $0.category == event.reading.category && ($0.period ?? .morning) == period
                }) {
                    let localUpdatedAt = logs[logIndex].readings[readingIndex].recordedAt ?? .distantPast
                    guard event.updatedAt > localUpdatedAt else { continue }

                    if event.isDeleted {
                        logs[logIndex].readings.remove(at: readingIndex)
                        if logs[logIndex].readings.isEmpty { logs.remove(at: logIndex) }
                    } else {
                        var remoteReading = event.reading
                        remoteReading.recordedAt = event.updatedAt
                        logs[logIndex].readings[readingIndex] = remoteReading
                    }
                    changes += 1
                } else if !event.isDeleted {
                    var remoteReading = event.reading
                    remoteReading.recordedAt = event.updatedAt
                    logs[logIndex].readings.append(remoteReading)
                    changes += 1
                }
            } else if !event.isDeleted {
                var remoteReading = event.reading
                remoteReading.recordedAt = event.updatedAt
                logs.append(DayLog(date: event.date, readings: [remoteReading]))
                changes += 1
            }
        }

        guard changes > 0 else { return 0 }
        logs.sort { $0.date > $1.date }
        recomputeLastPeriodStart()
        save()
        return changes
    }

    // MARK: - Ask Vida quota

    var askLimit: Int { isPlus ? .max : Self.freeAskLimit }
    var askRemaining: Int { isPlus ? .max : max(0, askLimit - askedCountToday) }

    func consumeAsk() {
        guard !isPlus else { return }
        askedCountToday += 1
        save()
    }

    // MARK: - Diary

    /// Adds or updates an entry. Empty text removes it, so clearing an entry
    /// and saving is the same as deleting it.
    func saveDiary(_ entry: DiaryEntry) {
        var entry = entry
        entry.text = String(entry.text.prefix(DiaryEntry.limit))
        entry.updatedAt = .now
        let isEmpty = entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        diary.removeAll { $0.id == entry.id }
        if !isEmpty {
            diary.append(entry)
            diary.sort { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
        }
        save()
    }

    func deleteDiary(_ entry: DiaryEntry) {
        diary.removeAll { $0.id == entry.id }
        save()
    }

    /// The entry written at the end of this period's check-in today, if any.
    func diaryEntry(on date: Date, period: CheckInPeriod) -> DiaryEntry? {
        diary.first { $0.period == period && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// Every day that has either writing or a check-in, newest first, so the
    /// diary reads as one record of her life with her check-ins woven in.
    var diaryDays: [Date] {
        let calendar = Calendar.current
        var days = Set(diary.map { calendar.startOfDay(for: $0.date) })
        days.formUnion(logs.map { calendar.startOfDay(for: $0.date) })
        return days.sorted(by: >)
    }

    func diaryEntries(on day: Date) -> [DiaryEntry] {
        diary.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
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
        meals = []
        lastLabNotesMonth = nil
        experiments = []
        preps = []
        diary = []
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
        let key = snapshotKey
        resetInMemory()
        if let key {
            defaults.removeObject(forKey: key)
            diaryVault.delete(accountKey: key)
        }
    }

    // MARK: - Meals

    func meals(on date: Date) -> [MealEntry] {
        let day = Calendar.current.startOfDay(for: date)
        return meals
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date < $1.date }
    }

    func addMeal(_ meal: MealEntry) {
        meals.append(meal)
        save()
    }

    func updateMeal(_ meal: MealEntry) {
        guard let index = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        meals[index] = meal
        save()
    }

    func deleteMeal(id: UUID) {
        meals.removeAll { $0.id == id }
        save()
    }

    // MARK: - Lab Notes

    /// Last month's recap, if there is one worth showing and it hasn't been
    /// shown yet.
    ///
    /// Reports on the month just *finished* rather than the one in progress —
    /// a recap of a month with four days in it isn't a recap.
    func pendingLabNotes(now: Date = .now) -> LabNotes? {
        let calendar = Calendar.current
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
              let interval = calendar.dateInterval(of: .month, for: lastMonth) else { return nil }

        if let shown = lastLabNotesMonth,
           calendar.isDate(shown, equalTo: interval.start, toGranularity: .month) {
            return nil
        }

        return LabNotesEngine.build(
            month: interval.start,
            logs: logs,
            meals: meals,
            experiments: experiments,
            links: meaningfulLinks,
            profile: profile
        )
    }

    func markLabNotesSeen(_ notes: LabNotes) {
        lastLabNotesMonth = notes.month
        save()
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

    /// Applies what vidalab.co's purchase records say about this account.
    ///
    /// Runs after the App Store check. `nil` means the lookup failed, and, as
    /// with the store, leaves everything as it was. An App Store membership
    /// always wins, because it carries renewal and grace details the web
    /// record doesn't; the web one only fills in when nothing else grants
    /// access, and only a web-sourced membership can be ended by it.
    func reconcileWebMembership(_ hasPaidWebMembership: Bool?) {
        guard let hasPaidWebMembership else { return }
        if hasPaidWebMembership {
            guard !entitlement.hasAccess else { return }
            applyEntitlement(
                status: .active,
                source: .web,
                plan: "Vida+",
                detail: "Membership bought on vidalab.co."
            )
        } else if entitlement.source == .web, entitlement.hasAccess {
            applyEntitlement(
                status: .expired,
                source: .web,
                detail: "The vidalab.co membership has ended. Downgraded to Vida Free; all data retained."
            )
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

    private var snapshotKey: String? {
        activeAccountID.map { "vida.snapshot.v2.\($0)" }
    }

    /// Returns the store to the exact state of a fresh account without touching
    /// another account's persisted journal.
    private func resetInMemory() {
        diaryLocked = false
        pendingLegacyDiary = nil
        name = ""
        hasOnboarded = false
        isPlus = false
        profile = HealthProfile()
        avatarData = nil
        reportEmail = ""
        weeklyReportEnabled = false
        lastReportSent = nil
        appearance = .dark
        logs = []
        meals = []
        experiments = []
        preps = []
        diary = []
        lastLabNotesMonth = nil
        savedArticleIDs = []
        askedCountToday = 0
        planName = ""
        entitlement = Entitlement()
        lastPeriodStart = nil
        averageCycleLength = 28
        healthSyncEnabled = false
        lastHealthSync = nil
    }

    private struct Snapshot: Codable {
        var name: String
        var hasOnboarded: Bool
        var isPlus: Bool
        var logs: [DayLog]
        var experiments: [Experiment]
        var preps: [DoctorPrep]
        /// Optional so snapshots written before the diary existed decode.
        var diary: [DiaryEntry]?
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
        /// Optional for the same reason: snapshots predating meal logging.
        var meals: [MealEntry]?
        var lastLabNotesMonth: Date?
        /// Optional for the same reason: snapshots predating deletion sync.
        var pendingDeletions: [DeletedReadingMarker]?
    }

    func save() {
        guard persistent, let snapshotKey else { return }
        let snapshot = Snapshot(
            name: name, hasOnboarded: hasOnboarded, isPlus: isPlus, logs: logs,
            experiments: experiments, preps: preps, diary: snapshotDiary(for: snapshotKey), savedArticleIDs: Array(savedArticleIDs),
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
            entitlement: entitlement,
            meals: meals,
            lastLabNotesMonth: lastLabNotesMonth,
            pendingDeletions: pendingDeletions
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    private func load() {
        guard let snapshotKey,
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        name = snapshot.name
        hasOnboarded = snapshot.hasOnboarded
        isPlus = snapshot.isPlus
        logs = snapshot.logs
        meals = snapshot.meals ?? []
        pendingDeletions = snapshot.pendingDeletions ?? []
        lastLabNotesMonth = snapshot.lastLabNotesMonth
        experiments = snapshot.experiments
        preps = snapshot.preps
        let legacyDiary = snapshot.diary
        switch diaryVault.read(accountKey: snapshotKey) {
        case .entries(let saved):
            diary = Self.mergedDiary(saved, legacyDiary ?? [])
        case .missing:
            diary = legacyDiary ?? []
        case .locked:
            diary = []
            diaryLocked = true
            pendingLegacyDiary = legacyDiary
        }
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
        appearance = snapshot.appearance.flatMap { VidaAppearance(rawValue: $0) } ?? .dark
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

        // Forest became the default after some members were saved on
        // Automatic or Daylight. Move everyone to Forest once; after that,
        // whatever she picks in Settings > Appearance stands.
        let forestDefaultKey = "vida.appearance.forestDefault.v1"
        if !defaults.bool(forKey: forestDefaultKey) {
            defaults.set(true, forKey: forestDefaultKey)
            if appearance != .dark {
                appearance = .dark
                save()
            }
        }

        // Diaries saved before the vault existed move into it now, and leave
        // the snapshot.
        if legacyDiary != nil && !diaryLocked { save() }
    }

    // MARK: - Diary vault

    /// What the snapshot should carry for the diary: nothing, once the vault
    /// holds it. If the vault can't be written, the diary stays in the snapshot
    /// rather than being lost, and moves on the next save.
    private func snapshotDiary(for key: String) -> [DiaryEntry]? {
        if diaryLocked { return pendingLegacyDiary }
        return diaryVault.write(diary, accountKey: key) ? nil : diary
    }

    /// Opens the diary if it was locked at launch. Call when the app becomes
    /// active or protected data becomes available.
    func reloadDiaryIfLocked() {
        guard diaryLocked, let snapshotKey else { return }
        guard case .entries(let saved) = diaryVault.read(accountKey: snapshotKey) else { return }
        diary = Self.mergedDiary(saved, pendingLegacyDiary ?? [])
        diaryLocked = false
        pendingLegacyDiary = nil
    }

    /// Entries from both places, one per id, keeping the most recently edited.
    static func mergedDiary(_ a: [DiaryEntry], _ b: [DiaryEntry]) -> [DiaryEntry] {
        var byID: [UUID: DiaryEntry] = [:]
        for entry in a + b {
            if let existing = byID[entry.id], existing.updatedAt >= entry.updatedAt { continue }
            byID[entry.id] = entry
        }
        return byID.values.sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
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
