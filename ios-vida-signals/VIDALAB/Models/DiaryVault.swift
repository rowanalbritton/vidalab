import Foundation

/// Where the diary lives on the phone: one file per account, with iOS's
/// strongest file protection, so the words are unreadable whenever the phone
/// is locked. Nothing else in the app writes here, and it is never uploaded.
///
/// The rest of the journal is kept in UserDefaults, which iOS only protects up
/// to "after first unlock". The diary is the most personal thing in the app,
/// so it sits apart from that, under complete protection.
nonisolated struct DiaryVault {
    enum ReadResult: Equatable {
        /// No diary saved yet for this account.
        case missing
        /// The phone is locked, so the file exists but can't be opened.
        case locked
        case entries([DiaryEntry])
    }

    let directory: URL

    static let standard = DiaryVault(
        directory: FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Diary", isDirectory: true)
    )

    func fileURL(for accountKey: String) -> URL {
        let safe = accountKey.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" }
        return directory.appendingPathComponent(String(safe) + ".json")
    }

    func read(accountKey: String) -> ReadResult {
        let url = fileURL(for: accountKey)
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .locked }
        guard let entries = try? JSONDecoder().decode([DiaryEntry].self, from: data) else {
            // Unreadable contents are treated like a locked file: never
            // overwritten, so nothing is lost if a later version can read it.
            return .locked
        }
        return .entries(entries)
    }

    /// Writes the whole diary with complete file protection. Returns false if
    /// it couldn't be written (for example, the phone is locked).
    @discardableResult
    func write(_ entries: [DiaryEntry], accountKey: String) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL(for: accountKey), options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }

    func delete(accountKey: String) {
        try? FileManager.default.removeItem(at: fileURL(for: accountKey))
    }
}
