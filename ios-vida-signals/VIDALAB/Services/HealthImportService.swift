import Foundation
import HealthKit

/// One signal VIDA LAB knows how to read from Apple Health.
nonisolated struct HealthSignalMapping: Identifiable, Hashable {
    let id: String
    let category: SignalCategory
    let sourceLabel: String
    let explanation: String
}

/// Reads sleep, movement, cycle and symptom data out of Apple Health and turns
/// it into VIDA LAB readings.
///
/// Apple Health is the hub every major wearable already writes into — Oura,
/// Apple Watch, Garmin, Whoop and Fitbit all sync there — so reading from
/// HealthKit covers all of them without a separate integration for each.
@Observable
final class HealthImportService {
    enum Phase: Equatable {
        case idle
        case requesting
        case importing
        case finished(imported: Int, days: Int)
        case failed(String)
        case unavailable
    }

    private(set) var phase: Phase = .idle
    /// Whether the member has ever been through the Apple Health permission sheet.
    private(set) var hasRequestedAccess: Bool
    /// True while a silent refresh is running, so the UI can stay calm.
    private(set) var isRefreshingQuietly: Bool = false

    private let store: HKHealthStore?
    private let defaults = UserDefaults.standard
    private let requestedKey = "vida.health.requested"

    /// Live queries that fire while the app is open, so a nap recorded by her
    /// ring at 2pm shows up without her pressing anything.
    private var observerQueries: [HKObserverQuery] = []
    private weak var linkedStore: VidaStore?
    private var lastAutoSync: Date?

    /// How stale data has to get before returning to the app triggers a refresh.
    private let autoSyncInterval: TimeInterval = 15 * 60

    /// Everything VIDA LAB reads, in the order shown on the connect screen.
    static let mappings: [HealthSignalMapping] = [
        .init(id: "sleep", category: .sleep, sourceLabel: "Sleep analysis",
              explanation: "Hours actually asleep, from your ring, watch or phone."),
        .init(id: "movement", category: .movement, sourceLabel: "Steps",
              explanation: "Daily step count, scaled onto Vida's 0–10 footing."),
        .init(id: "cycle", category: .cycle, sourceLabel: "Cycle tracking",
              explanation: "Flow you've recorded in Health or another cycle app."),
        .init(id: "headache", category: .headache, sourceLabel: "Headache",
              explanation: "Headache symptoms logged anywhere on your iPhone."),
        .init(id: "pain", category: .pain, sourceLabel: "Abdominal cramps",
              explanation: "Cramping logged as a symptom in Health."),
        .init(id: "energy", category: .energy, sourceLabel: "Fatigue",
              explanation: "Fatigue entries, read as the inverse of energy.")
    ]

    var isAvailable: Bool { store != nil }

    init() {
        store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
        hasRequestedAccess = defaults.bool(forKey: requestedKey)
        if store == nil { phase = .unavailable }
    }

    private var sampleTypes: [HKSampleType] {
        [
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.menstrualFlow),
            HKCategoryType(.headache),
            HKCategoryType(.abdominalCramps),
            HKCategoryType(.fatigue),
            HKQuantityType(.stepCount),
            HKQuantityType(.appleExerciseTime),
            // Body metrics, read for the Body metrics screen only: what an
            // Apple Watch or Oura Ring records overnight and through the day.
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.appleSleepingWristTemperature),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.mindfulSession)
        ]
    }

    private var readTypes: Set<HKObjectType> {
        Set(sampleTypes.map { $0 as HKObjectType })
    }

    /// Whether Apple would actually show the permission sheet if we asked.
    ///
    /// Apple never reveals which read permissions were granted, but it will say
    /// whether it still needs to ask. That's enough to avoid throwing a
    /// permission sheet at someone who already dealt with it.
    func needsPermissionPrompt() async -> Bool {
        guard let store else { return false }
        do {
            let status = try await store.statusForAuthorizationRequest(toShare: [], read: readTypes)
            return status == .shouldRequest
        } catch {
            return !hasRequestedAccess
        }
    }

    /// Presents Apple's permission sheet. Apple deliberately never tells an app
    /// which read permissions were granted, so this only reports that the sheet
    /// was completed — the import itself is what reveals what we can see.
    func requestAccess() async {
        guard let store else {
            phase = .unavailable
            return
        }
        phase = .requesting
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            hasRequestedAccess = true
            defaults.set(true, forKey: requestedKey)
            phase = .idle
        } catch {
            // The code, not the payload: HealthKit errors name types, never data.
            let nsError = error as NSError
            #if DEBUG
            NSLog("VIDA health authorization failed: %@ %ld %@", nsError.domain, nsError.code, nsError.localizedDescription)
            #endif
            phase = .failed("Apple Health didn't grant access. You can change this in Settings › Health › Data Access.")
        }
    }

    /// For SwiftUI's `healthDataAccessRequest` modifier, which presents Apple's
    /// sheet from the screen that asked. The older call can't present over a
    /// full-screen cover, which is where onboarding lives.
    var authorizationStore: HKHealthStore? { store }
    var authorizationTypes: Set<HKObjectType> { readTypes }

    /// Records the outcome of a sheet shown by `healthDataAccessRequest`.
    func recordAuthorization(_ result: Result<Bool, any Error>) {
        switch result {
        case .success:
            hasRequestedAccess = true
            defaults.set(true, forKey: requestedKey)
            phase = .idle
        case .failure(let error):
            let nsError = error as NSError
            #if DEBUG
            NSLog("VIDA health authorization failed: %@ %ld %@", nsError.domain, nsError.code, nsError.localizedDescription)
            #endif
            phase = .failed("Apple Health didn't grant access. You can change this in Settings › Health › Data Access.")
        }
    }

    /// The whole connection in one call: ask once, import immediately, then keep
    /// watching. Nothing else in the app needs to know the sequence.
    @discardableResult
    func connect(into vidaStore: VidaStore) async -> Int {
        if await needsPermissionPrompt() || !hasRequestedAccess {
            await requestAccess()
        }
        return await connectAfterAuthorization(into: vidaStore)
    }

    /// The import half of `connect`, for when the permission sheet was already
    /// shown by the calling view.
    @discardableResult
    func connectAfterAuthorization(into vidaStore: VidaStore) async -> Int {
        if case .failed = phase { return 0 }
        // Reach back a full quarter on the first connect: she may have months of
        // wearable history already sitting there, and patterns need a run-up.
        let imported = await importRecent(days: 90, into: vidaStore)
        // Hold the connection open even if Health was empty today.
        vidaStore.markHealthConnected()
        startObserving(into: vidaStore)
        return imported
    }

    /// Refreshes behind her attention — on launch and whenever she returns to the
    /// app. Throttled, silent, and never shows a spinner.
    func syncIfNeeded(into vidaStore: VidaStore) async {
        guard store != nil, vidaStore.healthSyncEnabled, hasRequestedAccess else { return }
        if let last = lastAutoSync, Date().timeIntervalSince(last) < autoSyncInterval { return }
        await importRecent(days: 14, into: vidaStore, quietly: true)
        startObserving(into: vidaStore)
    }

    /// Watches Health for new samples, so a nap her ring recorded this afternoon
    /// lands without her asking for it. Apple delivers these on a background
    /// queue, so each update hops back to the main actor.
    func startObserving(into vidaStore: VidaStore) {
        guard let store, observerQueries.isEmpty, vidaStore.healthSyncEnabled else { return }
        linkedStore = vidaStore

        for type in sampleTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard error == nil else {
                    // Always call the completion handler, even on failure, or iOS
                    // treats the delivery as unhandled and backs off.
                    completion()
                    return
                }
                Task { @MainActor in
                    defer { completion() }
                    guard let self, let target = self.linkedStore, target.healthSyncEnabled else { return }
                    await self.importRecent(days: 7, into: target, quietly: true)
                }
            }
            store.execute(query)
            observerQueries.append(query)
        }

        enableBackgroundDelivery(store: store)
    }

    /// Asks iOS to wake Vida when new health data arrives while the app is shut.
    ///
    /// Hourly rather than immediate on purpose: nothing here is urgent enough to
    /// justify spending her battery, and sleep data arrives in one morning batch
    /// anyway. If the entitlement is missing this simply fails and the in-app
    /// observers carry on doing the work.
    private func enableBackgroundDelivery(store: HKHealthStore) {
        for type in sampleTypes {
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    /// Stops watching the moment she disconnects.
    func stopObserving() {
        guard let store else { return }
        for query in observerQueries { store.stop(query) }
        observerQueries.removeAll()
        store.disableAllBackgroundDelivery { _, _ in }
        linkedStore = nil
        lastAutoSync = nil
    }

    /// Pulls the last `days` days of data and merges it into the store.
    /// Anything the member typed herself always wins.
    ///
    /// A quiet import does the same work without touching `phase`, so automatic
    /// refreshes never flicker status text she didn't ask to see.
    @discardableResult
    func importRecent(days: Int = 30, into vidaStore: VidaStore, quietly: Bool = false) async -> Int {
        guard let store else {
            if !quietly { phase = .unavailable }
            return 0
        }
        if quietly {
            isRefreshingQuietly = true
        } else {
            phase = .importing
        }
        defer { isRefreshingQuietly = false }

        let calendar = Calendar.current
        let end = Date()
        guard let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: end)) else {
            if !quietly { phase = .failed("Couldn't work out the date range to import.") }
            return 0
        }

        var byDay: [Date: [SignalReading]] = [:]

        func add(_ reading: SignalReading, on day: Date) {
            let key = calendar.startOfDay(for: day)
            var existing = byDay[key] ?? []
            if let index = existing.firstIndex(where: { $0.category == reading.category }) {
                existing[index] = reading
            } else {
                existing.append(reading)
            }
            byDay[key] = existing
        }

        do {
            // Sleep describes the night, so it belongs to the morning account.
            // Everything else summarises the whole day and lands in the evening.
            for (day, hours) in try await sleepHours(store: store, from: start, to: end) {
                add(SignalReading(category: .sleep, value: hours, source: .appleHealth, period: .morning), on: day)
            }
            for (day, steps) in try await stepTotals(store: store, from: start, to: end) {
                let scaled = min(10, (steps / 1000).rounded())
                add(SignalReading(category: .movement, value: scaled,
                                  tags: ["\(Int(steps)) steps"], source: .appleHealth, period: .evening), on: day)
            }
            for (day, value) in try await flowValues(store: store, from: start, to: end) {
                add(SignalReading(category: .cycle, value: value, source: .appleHealth, period: .evening), on: day)
            }
            for (day, value) in try await severityValues(.headache, store: store, from: start, to: end) {
                add(SignalReading(category: .headache, value: value, source: .appleHealth, period: .evening), on: day)
            }
            for (day, value) in try await severityValues(.abdominalCramps, store: store, from: start, to: end) {
                add(SignalReading(category: .pain, value: value, tags: ["Abdomen"], source: .appleHealth, period: .evening), on: day)
            }
            for (day, value) in try await severityValues(.fatigue, store: store, from: start, to: end) {
                // Fatigue is the inverse of energy: severe fatigue means very little energy.
                add(SignalReading(category: .energy, value: max(0, 10 - value), source: .appleHealth, period: .evening), on: day)
            }
        } catch {
            if !quietly {
                phase = .failed("Apple Health couldn't be read right now. If you haven't granted access, open Settings › Health › Data Access › VIDA LAB.")
            }
            return 0
        }

        let imported = vidaStore.mergeHealthReadings(byDay)
        lastAutoSync = .now
        if !quietly {
            phase = .finished(imported: imported, days: byDay.keys.count)
        }
        return imported
    }

    // MARK: - Queries

    private func sleepHours(store: HKHealthStore, from start: Date, to end: Date) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let calendar = Calendar.current
        var totals: [Date: Double] = [:]
        for sample in samples where asleepValues.contains(sample.value) {
            // A night is attributed to the morning you woke up on.
            let day = calendar.startOfDay(for: sample.endDate)
            let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
            totals[day, default: 0] += hours
        }
        return totals.mapValues { ((min(14, $0)) * 10).rounded() / 10 }
    }

    private func stepTotals(store: HKHealthStore, from start: Date, to end: Date) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.stepCount), predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        let calendar = Calendar.current
        var totals: [Date: Double] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            totals[day, default: 0] += sample.quantity.doubleValue(for: .count())
        }
        return totals
    }

    private func flowValues(store: HKHealthStore, from start: Date, to end: Date) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.menstrualFlow), predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        let calendar = Calendar.current
        var values: [Date: Double] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            let mapped: Double
            switch sample.value {
            case HKCategoryValueVaginalBleeding.none.rawValue: mapped = 0
            case HKCategoryValueVaginalBleeding.light.rawValue: mapped = 3
            case HKCategoryValueVaginalBleeding.medium.rawValue: mapped = 6
            case HKCategoryValueVaginalBleeding.heavy.rawValue: mapped = 9
            default: mapped = 5
            }
            values[day] = max(values[day] ?? 0, mapped)
        }
        return values
    }

    private func severityValues(
        _ identifier: HKCategoryTypeIdentifier,
        store: HKHealthStore,
        from start: Date,
        to end: Date
    ) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(identifier), predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        let calendar = Calendar.current
        var values: [Date: Double] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            let mapped: Double
            switch sample.value {
            case HKCategoryValueSeverity.notPresent.rawValue: mapped = 0
            case HKCategoryValueSeverity.mild.rawValue: mapped = 3
            case HKCategoryValueSeverity.moderate.rawValue: mapped = 6
            case HKCategoryValueSeverity.severe.rawValue: mapped = 9
            default: mapped = 5
            }
            // Keep the worst report of the day — that's what she'd remember.
            values[day] = max(values[day] ?? 0, mapped)
        }
        return values
    }
}
