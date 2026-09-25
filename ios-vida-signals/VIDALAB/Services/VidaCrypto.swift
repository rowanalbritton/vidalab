import Foundation
import CryptoKit
import Security

/// Client-side encryption for everything health-related that leaves the phone.
///
/// VIDA LAB's whole position is that nobody but the member can read her
/// symptoms. Sync would normally destroy that: the moment check-ins land in a
/// database, whoever holds the database can read them. So nothing readable is
/// ever uploaded — payloads are sealed with AES-GCM using a key that exists
/// only in her Keychain, and the server stores ciphertext it has no way to open.
///
/// The key lives in the **iCloud Keychain** (`kSecAttrSynchronizable`), which is
/// the deliberate trade-off at the centre of this design:
///
/// - Signing in on a new iPhone with the same Apple ID brings the key along, so
///   a year of history survives a lost phone — the entire reason to have an
///   account in the first place.
/// - Apple's keychain escrow is end-to-end encrypted, so the key still never
///   reaches Vida's servers, and we still cannot read a single entry.
/// - If she disables iCloud Keychain and loses the device, the data is
///   genuinely unrecoverable. That is an honest cost of real encryption, and
///   the privacy policy says so plainly rather than hiding it.
nonisolated enum VidaCrypto {
    private static let keyAccount = "vida.sync.datakey.v1"

    enum CryptoError: LocalizedError, Equatable {
        case keyUnavailable
        case sealFailed
        case openFailed

        var errorDescription: String? {
            switch self {
            case .keyUnavailable:
                "Vida couldn't reach this device's encryption key, so nothing was uploaded. Your entries are safe on this phone."
            case .sealFailed:
                "Vida couldn't encrypt that entry, so it wasn't uploaded. It's still saved on this phone."
            case .openFailed:
                "Some synced entries couldn't be unlocked on this device. They may have been saved with a different iCloud Keychain."
            }
        }
    }

    /// True once a data key exists. Used to tell "new member" apart from
    /// "restored onto a device that can't decrypt anything".
    static var hasKey: Bool { loadKeyData() != nil }

    // MARK: - Sealing

    /// Encrypts any Codable payload into a base64 string safe to store remotely.
    static func encrypt<T: Encodable>(_ value: T) throws -> String {
        let key = try dataKey()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let plaintext = try? encoder.encode(value),
              let sealed = try? AES.GCM.seal(plaintext, using: key),
              let combined = sealed.combined else {
            throw CryptoError.sealFailed
        }
        return combined.base64EncodedString()
    }

    /// Opens a payload sealed by `encrypt`. Throws `.openFailed` when the
    /// ciphertext was written under a different key rather than crashing.
    static func decrypt<T: Decodable>(_ type: T.Type, from ciphertext: String) throws -> T {
        let key = try dataKey()

        guard let data = Data(base64Encoded: ciphertext),
              let box = try? AES.GCM.SealedBox(combined: data),
              let plaintext = try? AES.GCM.open(box, using: key) else {
            throw CryptoError.openFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let value = try? decoder.decode(type, from: plaintext) else {
            throw CryptoError.openFailed
        }
        return value
    }

    /// A stable, per-member opaque handle for a plaintext identifier.
    ///
    /// Used for saved-article rows: *which* article someone saves is itself
    /// revealing — a list of endometriosis and thyroid titles is a diagnosis in
    /// all but name. An HMAC under her own key lets sync deduplicate without
    /// the server ever learning what she read.
    static func reference(for identifier: String) throws -> String {
        let key = try dataKey()
        let code = HMAC<SHA256>.authenticationCode(for: Data(identifier.utf8), using: key)
        return Data(code).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Escrow hooks

    /// Raw key bytes, for `VidaKeyEscrow` only.
    ///
    /// Exposing key material at all is a deliberate, narrow exception: the
    /// passphrase escrow has to seal the key itself, and it cannot do that
    /// without holding it. The bytes must never be logged, written to disk, or
    /// sent anywhere except sealed under a passphrase-derived key.
    ///
    /// Creates the key if there isn't one, so escrow can be set up before the
    /// first sync has ever run.
    static func exportKeyMaterial() throws -> Data {
        let key = try dataKey()
        return key.withUnsafeBytes { Data($0) }
    }

    /// Installs a key recovered from escrow, replacing whatever this device
    /// had. Used when a new phone or a reinstall adopts the existing key —
    /// without this, restored rows would be ciphertext the device can't open.
    static func installKeyMaterial(_ raw: Data) throws {
        guard raw.count == 32 else { throw CryptoError.keyUnavailable }
        keyLock.lock()
        defer { keyLock.unlock() }
        guard storeKeyData(raw) else { throw CryptoError.keyUnavailable }
    }

    // MARK: - Key management

    /// Serialises creating and replacing the key.
    ///
    /// `storeKeyData` deletes before it adds, which is not atomic. Two callers
    /// reaching first-use together could each complete and each believe in a
    /// different key — and whichever lost the race would go on sealing data
    /// under a key that is no longer in the Keychain, making it permanently
    /// unreadable. Cheap lock, unbounded cost if it's missing.
    private static let keyLock = NSLock()

    /// Fetches the data key, creating one on first use.
    private static func dataKey() throws -> SymmetricKey {
        if let existing = loadKeyData() {
            return SymmetricKey(data: existing)
        }

        keyLock.lock()
        defer { keyLock.unlock() }

        // Re-check inside the lock: another caller may have created the key
        // while this one was waiting, and that key is now the real one.
        if let existing = loadKeyData() {
            return SymmetricKey(data: existing)
        }

        let fresh = SymmetricKey(size: .bits256)
        let raw = fresh.withUnsafeBytes { Data($0) }
        guard storeKeyData(raw) else { throw CryptoError.keyUnavailable }
        return fresh
    }

    private static func loadKeyData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyAccount,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, data.count == 32 else {
            return nil
        }
        return data
    }

    private static func storeKeyData(_ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyAccount,
            kSecAttrSynchronizable as String: true,
            // Sync runs on return-to-foreground, which can happen before the
            // first unlock of the day; AfterFirstUnlock is also the strictest
            // class Apple allows to ride the iCloud Keychain.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Destroys the local key, making any remaining ciphertext permanently
    /// unreadable. Called from full account deletion — this is what makes
    /// "delete everything" true for data already uploaded.
    static func destroyKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyAccount,
            kSecAttrSynchronizable as String: true
        ]
        SecItemDelete(query as CFDictionary)
    }
}
