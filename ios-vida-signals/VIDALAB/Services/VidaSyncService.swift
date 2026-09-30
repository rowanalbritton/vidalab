import Foundation
import Supabase

/// Cloud backup for signed-in members, so a year of her own data survives a
/// lost phone.
///
/// Three rules hold this together:
///
/// 1. **Local storage stays the source of truth.** `VidaStore` keeps writing to
///    the device exactly as before; this class only copies upward and, on a
///    fresh install, merges downward. Nothing here can delete a local entry.
/// 2. **Everything health-related is encrypted on the phone first.** The server
///    holds ciphertext and a date — never a symptom, score or note.
/// 3. **Failure is silent and safe.** No spinner on the home screen, no alert
///    mid-check-in. If sync can't run, the app is exactly the app it was
///    before sync existed.
@Observable
final class VidaSyncService {
    /// What the last sync attempt did. Surfaced quietly in Settings only.
    enum State: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }

    private(set) var state: State = .idle

    private let defaults = UserDefaults.standard
    private var lastPush: Date?
    private var isRunning: Bool = false

    private static let checkInEventMigrationPrefix = "vida.migration.checkin-events.v1."
    private static let checkInEventPushPrefix = "vida.sync.checkin-events.last-push.v1."

    /// Foreground syncs are throttled — returning to the app ten times an hour
    /// should not mean ten round trips.
    private let minimumInterval: TimeInterval = 5 * 60

    /// Migration state belongs to an account, not to the phone. A global flag
    /// could make the second member to sign in on a shared device skip the
    /// initial cloud restore entirely.
    private func hasMigrated(userID: String) -> Bool {
        defaults.bool(forKey: Self.migrationFlagKey(for: userID))
    }

    nonisolated static func migrationFlagKey(for userID: String) -> String {
        "vida.migration.supabase.v2." + userID
    }

    nonisolated static func checkInEventMigrationFlagKey(for userID: String) -> String {
        checkInEventMigrationPrefix + userID
    }

    nonisolated static func checkInEventLastPushKey(for userID: String) -> String {
        checkInEventPushPrefix + userID
    }

    // MARK: - Entry point

    /// Called after sign-in and on return to foreground.
    ///
    /// Order matters: pull before push on a device that has never migrated, so
    /// a reinstall recovers her history instead of overwriting the cloud copy
    /// with an empty local one.
    @MainActor
    func syncIfNeeded(store: VidaStore, userID: String, email: String?, name: String?, force: Bool = false) async {
        guard !isRunning else { return }
        if !force, let last = lastPush, Date().timeIntervalSince(last) < minimumInterval { return }

        isRunning = true
        state = .syncing
        defer { isRunning = false }

        do {
            try await upsertProfile(userID: userID, email: email, name: name)

            if !hasMigrated(userID: userID) {
                try await restore(into: store, userID: userID)
                try await restoreCheckInEvents(into: store)
                try await pushEverything(store: store, userID: userID)
                // Flag is set only after a complete round trip. A failure
                // part-way leaves it unset so the next launch retries rather
                // than marking migration done with half the data uploaded.
                defaults.set(true, forKey: Self.migrationFlagKey(for: userID))
            } else {
                try await restoreCheckInEvents(into: store)
                try await pushEverything(store: store, userID: userID)
            }

            lastPush = Date()
            state = .synced(Date())
        } catch {
            state = .failed(Self.plainMessage(for: error))
            #if DEBUG
            #if DEBUG
            print("[VidaSync] failed: \(error)")
            #endif
            #endif
        }
    }

    // MARK: - Profile

    private func upsertProfile(userID: String, email: String?, name: String?) async throws {
        try await vidaSupabase
            .from("profiles")
            .upsert(ProfileUpsert(id: userID, email: email, name: name, updatedAt: Date()))
            .execute()
    }

    // MARK: - Push

    /// Uploads the full local set as encrypted upserts.
    ///
    /// Upserting everything rather than diffing is a deliberate simplicity
    /// trade: the payloads are tiny, the natural keys make repeats idempotent,
    /// and there is no local dirty-tracking to get out of step with reality.
    private func pushEverything(store: VidaStore, userID: String) async throws {
        try await pushCheckIns(store.logs, userID: userID)
        try await pushCheckInEvents(store: store, userID: userID)
        try await pushMeals(store.meals, userID: userID)
        try await pushExperiments(store.experiments, userID: userID)
        try await pushPreps(store.preps, userID: userID)
        try await pushSavedArticles(store.savedArticleIDs, userID: userID)
    }

    /// Meals are health data like everything else here — what someone ate is
    /// exactly the kind of detail this app promises to keep unreadable — so
    /// they travel encrypted under the same key, never as plain text.
    private func pushMeals(_ meals: [MealEntry], userID: String) async throws {
        guard !meals.isEmpty else { return }
        let rows = try meals.map { meal in
            ClientKeyedRow(
                userId: userID,
                clientId: meal.id.uuidString,
                ciphertext: try VidaCrypto.encrypt(meal),
                schemaVersion: 1,
                updatedAt: Date()
            )
        }
        try await vidaSupabase
            .from("meals")
            .upsert(rows, onConflict: "user_id,client_id")
            .execute()
    }

    private func pushCheckIns(_ logs: [DayLog], userID: String) async throws {
        guard !logs.isEmpty else { return }
        let rows = try logs.map { log in
            CheckInRow(
                userId: userID,
                localDate: VidaDateKey.string(from: log.date),
                ciphertext: try VidaCrypto.encrypt(log),
                schemaVersion: 1,
                updatedAt: Date()
            )
        }
        try await vidaSupabase
            .from("check_ins")
            .upsert(rows, onConflict: "user_id,local_date")
            .execute()
    }

    /// Dual-writes signal readings to the additive, per-reading event stream.
    /// Existing encrypted whole-day rows remain the recovery source until every
    /// supported client has adopted event-stream restore. A deterministic key
    /// makes retries and concurrent device edits idempotent; the server keeps
    /// the ciphertext carrying the newest client timestamp.
    @MainActor
    private func pushCheckInEvents(store: VidaStore, userID: String) async throws {
        let logs = store.logs
        let pendingDeletions = store.pendingDeletions
        let migrationKey = Self.checkInEventMigrationFlagKey(for: userID)
        let lastPushKey = Self.checkInEventLastPushKey(for: userID)
        let hasMigratedEvents = defaults.bool(forKey: migrationKey)
        let lastEventPush = defaults.object(forKey: lastPushKey) as? Date

        let edits = try logs.flatMap { log in
            try log.readings.compactMap { reading -> CheckInSyncEventRequest? in
                let updatedAt = reading.recordedAt ?? log.date
                if hasMigratedEvents, let lastEventPush, updatedAt <= lastEventPush {
                    return nil
                }

                let period = reading.period ?? .morning
                return CheckInSyncEventRequest(
                    clientId: CheckInSyncEventID.make(
                        userID: userID,
                        localDate: log.date,
                        category: reading.category,
                        period: period
                    ).uuidString.lowercased(),
                    localDate: VidaDateKey.string(from: log.date),
                    period: period.rawValue,
                    timezone: reading.timeZoneIdentifier,
                    ciphertext: try VidaCrypto.encrypt(reading),
                    schemaVersion: 1,
                    clientUpdatedAt: updatedAt,
                    deletedAt: nil
                )
            }
        }

        // Tombstones are never filtered by the push checkpoint: a deletion is
        // always news to the server, however old the reading it retires was.
        //
        // The payload is a reading stripped of its value, tags and note. The
        // table requires a ciphertext and restore decrypts one, so a tombstone
        // has to carry something — this carries only the category and period
        // the merge matches on, and no health detail at all.
        let tombstones = try pendingDeletions.map { marker in
            var placeholder = SignalReading(category: marker.category, value: 0)
            placeholder.period = marker.period
            placeholder.recordedAt = marker.deletedAt

            return CheckInSyncEventRequest(
                clientId: CheckInSyncEventID.make(
                    userID: userID,
                    localDate: marker.date,
                    category: marker.category,
                    period: marker.period
                ).uuidString.lowercased(),
                localDate: VidaDateKey.string(from: marker.date),
                period: marker.period.rawValue,
                timezone: nil,
                ciphertext: try VidaCrypto.encrypt(placeholder),
                schemaVersion: 1,
                clientUpdatedAt: marker.deletedAt,
                deletedAt: marker.deletedAt
            )
        }

        let events = edits + tombstones

        guard !events.isEmpty else {
            defaults.set(Date(), forKey: lastPushKey)
            defaults.set(true, forKey: migrationKey)
            return
        }

        var start = 0
        while start < events.count {
            let end = min(start + 50, events.count)
            let batch = CheckInSyncEventBatch(events: Array(events[start..<end]))
            let _: CheckInSyncEventResponse = try await vidaSupabase.functions.invoke(
                "sync-checkin-event",
                options: FunctionInvokeOptions(body: batch, encoder: vidaFunctionEncoder)
            )
            start = end
        }

        // Advance the checkpoint only after every batch succeeds. On a network
        // interruption the same stable IDs are resent safely on the next run.
        defaults.set(Date(), forKey: lastPushKey)
        defaults.set(true, forKey: migrationKey)
        // Only now are the deletions safe to forget. Clearing them earlier
        // would lose the tombstone on a failed push and let the reading come
        // back from the other device.
        store.clearPendingDeletions(pendingDeletions)
    }

    /// Pulls encrypted, per-reading events on every sync. RLS scopes this
    /// query to the signed-in member; no user identifier is accepted from the
    /// client, which prevents cached data from another account being restored.
    @MainActor
    private func restoreCheckInEvents(into store: VidaStore) async throws {
        let rows: [CheckInSyncEventRow] = try await vidaSupabase
            .from("ios_checkin_events")
            .select()
            .order("client_updated_at", ascending: true)
            .execute()
            .value

        let events = rows.compactMap { row -> SyncedCheckInReading? in
            guard let date = VidaDateKey.date(from: row.localDate),
                  var reading = try? VidaCrypto.decrypt(SignalReading.self, from: row.ciphertext) else {
                return nil
            }
            reading.period = CheckInPeriod(rawValue: row.period) ?? reading.period ?? .morning
            reading.timeZoneIdentifier = row.timezone ?? reading.timeZoneIdentifier
            return SyncedCheckInReading(
                date: date,
                reading: reading,
                updatedAt: row.deletedAt ?? row.clientUpdatedAt,
                isDeleted: row.deletedAt != nil
            )
        }
        store.mergeSyncedCheckInReadings(events)
    }

    private func pushExperiments(_ experiments: [Experiment], userID: String) async throws {
        guard !experiments.isEmpty else { return }
        let rows = try experiments.map { item in
            ClientKeyedRow(
                userId: userID,
                clientId: item.id.uuidString,
                ciphertext: try VidaCrypto.encrypt(item),
                schemaVersion: 1,
                updatedAt: Date()
            )
        }
        try await vidaSupabase
            .from("experiments")
            .upsert(rows, onConflict: "user_id,client_id")
            .execute()
    }

    private func pushPreps(_ preps: [DoctorPrep], userID: String) async throws {
        guard !preps.isEmpty else { return }
        let rows = try preps.map { prep in
            ClientKeyedRow(
                userId: userID,
                clientId: prep.id.uuidString,
                ciphertext: try VidaCrypto.encrypt(prep),
                schemaVersion: 1,
                updatedAt: Date()
            )
        }
        try await vidaSupabase
            .from("doctor_preps")
            .upsert(rows, onConflict: "user_id,client_id")
            .execute()
    }

    private func pushSavedArticles(_ ids: Set<String>, userID: String) async throws {
        guard !ids.isEmpty else { return }
        let rows = try ids.map { id in
            SavedArticleRow(
                userId: userID,
                articleRef: try VidaCrypto.reference(for: id),
                ciphertext: try VidaCrypto.encrypt(id)
            )
        }
        try await vidaSupabase
            .from("saved_articles")
            .upsert(rows, onConflict: "user_id,article_ref")
            .execute()
    }

    // MARK: - Restore

    /// Merges the cloud copy into local storage on a device that has never
    /// migrated — the lost-phone path.
    ///
    /// Local always wins a collision. Someone reinstalling and logging today
    /// before sync finishes should never see today's entry replaced by an
    /// older cloud row.
    @MainActor
    private func restore(into store: VidaStore, userID: String) async throws {
        let checkIns: [CheckInRow] = try await vidaSupabase
            .from("check_ins")
            .select()
            .order("local_date", ascending: false)
            .execute()
            .value

        var recoveredLogs: [DayLog] = []
        var undecryptable = 0
        for row in checkIns {
            guard let log = try? VidaCrypto.decrypt(DayLog.self, from: row.ciphertext) else {
                undecryptable += 1
                continue
            }
            let alreadyLocal = store.logs.contains {
                Calendar.current.isDate($0.date, inSameDayAs: log.date)
            }
            // Two rows can decrypt to the same day: `local_date` was computed
            // a day early outside the Americas before the VidaDateKey fix, so
            // an account synced across that change holds the mis-keyed
            // original and the corrected rewrite. The date sealed *inside* the
            // ciphertext was always right, so trust that and fold the pair
            // together rather than restoring the day twice.
            //
            // Checking the recovered set too, not just the local one — the
            // originals are both absent from local on a fresh install, which
            // is exactly when restore runs.
            let alreadyRecovered = recoveredLogs.contains {
                Calendar.current.isDate($0.date, inSameDayAs: log.date)
            }
            if !alreadyLocal && !alreadyRecovered { recoveredLogs.append(log) }
        }

        let mealRows: [ClientKeyedRow] = try await vidaSupabase
            .from("meals").select().execute().value
        let recoveredMeals = mealRows.compactMap {
            try? VidaCrypto.decrypt(MealEntry.self, from: $0.ciphertext)
        }.filter { candidate in
            !store.meals.contains { $0.id == candidate.id }
        }

        let experimentRows: [ClientKeyedRow] = try await vidaSupabase
            .from("experiments").select().execute().value
        let recoveredExperiments = experimentRows.compactMap {
            try? VidaCrypto.decrypt(Experiment.self, from: $0.ciphertext)
        }.filter { candidate in
            !store.experiments.contains { $0.id == candidate.id }
        }

        let prepRows: [ClientKeyedRow] = try await vidaSupabase
            .from("doctor_preps").select().execute().value
        let recoveredPreps = prepRows.compactMap {
            try? VidaCrypto.decrypt(DoctorPrep.self, from: $0.ciphertext)
        }.filter { candidate in
            !store.preps.contains { $0.id == candidate.id }
        }

        let articleRows: [SavedArticleRow] = try await vidaSupabase
            .from("saved_articles").select().execute().value
        let recoveredArticles = articleRows.compactMap {
            try? VidaCrypto.decrypt(String.self, from: $0.ciphertext)
        }

        store.absorbRestored(
            logs: recoveredLogs,
            meals: recoveredMeals,
            experiments: recoveredExperiments,
            preps: recoveredPreps,
            savedArticleIDs: Set(recoveredArticles)
        )

        if undecryptable > 0 {
            #if DEBUG
            #if DEBUG
            print("[VidaSync] \(undecryptable) rows sealed under a different key")
            #endif
            #endif
        }
    }

    // MARK: - Web access (passphrase escrow)

    /// Whether this account has a wrapped key stored, i.e. whether the website
    /// is able to read her data once she types the passphrase there.
    func hasWebAccess(userID: String) async -> Bool {
        await wrappedKey(userID: userID) != nil
    }

    func wrappedKey(userID: String) async -> VidaKeyEscrow.WrappedKey? {
        do {
            let rows: [SyncKeyRow] = try await vidaSupabase
                .from("sync_keys")
                .select()
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return nil }
            return VidaKeyEscrow.WrappedKey(
                kdf: row.kdf,
                salt: row.salt,
                iterations: row.iterations,
                wrappedKey: row.wrappedKey
            )
        } catch {
            return nil
        }
    }

    /// Turns on web access by storing this device's key sealed under a
    /// passphrase. The passphrase itself is never stored or transmitted.
    ///
    /// Not throttled and not silent, unlike the rest of this class: she asked
    /// for this one explicitly and is waiting on the answer.
    func enableWebAccess(passphrase: String, userID: String) async throws {
        let wrapped = try VidaKeyEscrow.wrapCurrentKey(passphrase: passphrase)
        let row = SyncKeyRow(
            userId: userID,
            kdf: wrapped.kdf,
            salt: wrapped.salt,
            iterations: wrapped.iterations,
            wrappedKey: wrapped.wrappedKey,
            updatedAt: Date()
        )
        try await vidaSupabase
            .from("sync_keys")
            .upsert(row, onConflict: "user_id")
            .execute()
    }

    /// Revokes web access. The data stays encrypted and the phone keeps
    /// working; only the browser's route in is removed.
    ///
    /// Worth being clear with her about the cost: this is also the escrow
    /// copy, so afterwards the iCloud Keychain is once again the only thing
    /// holding the key.
    func disableWebAccess(userID: String) async throws {
        try await vidaSupabase
            .from("sync_keys")
            .delete()
            .eq("user_id", value: userID)
            .execute()
    }

    // MARK: - Membership mirror

    /// Reads server-side membership standing. Advisory only — RevenueCat stays
    /// authoritative, and this never downgrades anyone on its own.
    func remoteEntitlement() async -> EntitlementRow? {
        do {
            let rows: [EntitlementRow] = try await vidaSupabase
                .from("entitlements")
                .select()
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            return nil
        }
    }

    // MARK: - Account deletion

    /// Removes every synced row, then destroys the local key so any copy that
    /// outlives the delete is permanently unreadable.
    @MainActor
    func deleteAllRemoteData(userID: String) async throws {
        // `sync_keys` belongs in this list: leaving the wrapped key behind
        // would mean the one artefact capable of unlocking any surviving
        // ciphertext outlives the account it was deleted with.
        for table in ["check_ins", "meals", "experiments", "doctor_preps", "saved_articles", "sync_keys"] {
            try await vidaSupabase.from(table).delete().eq("user_id", value: userID).execute()
        }
        try await vidaSupabase.from("profiles").delete().eq("id", value: userID).execute()
        VidaCrypto.destroyKey()
        defaults.removeObject(forKey: Self.migrationFlagKey(for: userID))
        defaults.removeObject(forKey: Self.checkInEventMigrationFlagKey(for: userID))
        defaults.removeObject(forKey: Self.checkInEventLastPushKey(for: userID))
        lastPush = nil
        state = .idle
    }

    /// Signing out must not leave the next person to hold the phone mid-sync.
    /// A caller can explicitly request a full restore after installing a
    /// recovered encryption key; ordinary sign-out retains each account's
    /// independent migration state.
    @MainActor
    func reset(requiresFullRestoreFor userID: String? = nil) {
        if let userID {
            defaults.removeObject(forKey: Self.migrationFlagKey(for: userID))
            defaults.removeObject(forKey: Self.checkInEventMigrationFlagKey(for: userID))
            defaults.removeObject(forKey: Self.checkInEventLastPushKey(for: userID))
        }
        lastPush = nil
        state = .idle
    }

    nonisolated static func plainMessage(for error: Error) -> String {
        if let cryptoError = error as? VidaCrypto.CryptoError {
            return cryptoError.errorDescription ?? "Backup didn't finish."
        }
        guard let urlError = error as? URLError else {
            return "Backup didn't finish. Your entries are saved on this phone, and Vida will try again later."
        }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "You're offline, so backup is paused. Everything you log is saved on this phone."
        case .timedOut:
            return "Backup took too long and Vida stopped waiting. It'll try again later."
        default:
            return "Backup didn't finish. Your entries are saved on this phone, and Vida will try again later."
        }
    }
}
