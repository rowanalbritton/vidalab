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

    private let migrationFlagKey = "vida.migration.supabase.v1"
    private let defaults = UserDefaults.standard
    private var lastPush: Date?
    private var isRunning: Bool = false

    /// Foreground syncs are throttled — returning to the app ten times an hour
    /// should not mean ten round trips.
    private let minimumInterval: TimeInterval = 5 * 60

    var hasMigrated: Bool { defaults.bool(forKey: migrationFlagKey) }

    // MARK: - Entry point

    /// Called after sign-in and on return to foreground.
    ///
    /// Order matters: pull before push on a device that has never migrated, so
    /// a reinstall recovers her history instead of overwriting the cloud copy
    /// with an empty local one.
    @MainActor
    func syncIfNeeded(store: VidaStore, userID: String, email: String?, name: String?, force: Bool = false) async {
        // No backend credentials means no sync target. Attempting it anyway
        // would spend the whole request timeout on every foreground before
        // reporting a failure that is really a build-configuration gap.
        guard VidaBackend.isConfigured else { return }
        guard !isRunning else { return }
        if !force, let last = lastPush, Date().timeIntervalSince(last) < minimumInterval { return }

        isRunning = true
        state = .syncing
        defer { isRunning = false }

        do {
            try await upsertProfile(userID: userID, email: email, name: name)

            if !hasMigrated {
                try await restore(into: store, userID: userID)
                try await pushEverything(store: store, userID: userID)
                // Flag is set only after a complete round trip. A failure
                // part-way leaves it unset so the next launch retries rather
                // than marking migration done with half the data uploaded.
                defaults.set(true, forKey: migrationFlagKey)
            } else {
                try await pushEverything(store: store, userID: userID)
            }

            lastPush = Date()
            state = .synced(Date())
        } catch {
            state = .failed(Self.plainMessage(for: error))
            #if DEBUG
            print("[VidaSync] failed: \(error)")
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
        try await pushExperiments(store.experiments, userID: userID)
        try await pushPreps(store.preps, userID: userID)
        try await pushSavedArticles(store.savedArticleIDs, userID: userID)
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
            if !alreadyLocal { recoveredLogs.append(log) }
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
            experiments: recoveredExperiments,
            preps: recoveredPreps,
            savedArticleIDs: Set(recoveredArticles)
        )

        if undecryptable > 0 {
            #if DEBUG
            print("[VidaSync] \(undecryptable) rows sealed under a different key")
            #endif
        }
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
        for table in ["check_ins", "experiments", "doctor_preps", "saved_articles"] {
            try await vidaSupabase.from(table).delete().eq("user_id", value: userID).execute()
        }
        try await vidaSupabase.from("profiles").delete().eq("id", value: userID).execute()
        VidaCrypto.destroyKey()
        defaults.removeObject(forKey: migrationFlagKey)
        lastPush = nil
        state = .idle
    }

    /// Signing out must not leave the next person to hold the phone mid-sync,
    /// and must let a re-sign-in re-run the merge.
    @MainActor
    func reset() {
        defaults.removeObject(forKey: migrationFlagKey)
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
