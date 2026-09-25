import Foundation
import CommonCrypto
import CryptoKit

/// Optional passphrase escrow, so the same encrypted data can be opened in a
/// browser without the server ever being able to open it.
///
/// The sync key itself does not change. It stays a random 256-bit value in the
/// iCloud Keychain, and every existing row stays readable exactly as before —
/// what this adds is a second, *wrapped* copy of that key: sealed under a key
/// derived from a passphrase only the member knows, and stored server-side as
/// ciphertext. The server holds the salt and the wrapped bytes and can do
/// nothing with either.
///
/// Wrapping rather than re-encrypting is the whole point. Re-keying would mean
/// downloading, opening and re-sealing a year of history on the phone, with a
/// half-migrated account as the failure mode. Wrapping touches one small record.
///
/// ### Deriving the same key on the web
///
/// PBKDF2-HMAC-SHA256 and AES-256-GCM were chosen because WebCrypto does both
/// natively — no library, no polyfill:
///
/// ```js
/// const enc = new TextEncoder();
/// // NFC matters: iOS normalises the passphrase before deriving, so the
/// // browser has to as well or an accented character silently won't match.
/// const material = await crypto.subtle.importKey(
///   "raw", enc.encode(passphrase.normalize("NFC")), "PBKDF2", false, ["deriveKey"]
/// );
/// const kek = await crypto.subtle.deriveKey(
///   { name: "PBKDF2", salt, iterations, hash: "SHA-256" },
///   material, { name: "AES-GCM", length: 256 }, false, ["decrypt"]
/// );
/// // wrapped = nonce(12) || ciphertext || tag(16)
/// const dataKeyBytes = await crypto.subtle.decrypt(
///   { name: "AES-GCM", iv: wrapped.slice(0, 12) }, kek, wrapped.slice(12)
/// );
/// ```
///
/// `dataKeyBytes` is then the raw 32-byte key that opens every `ciphertext`
/// column, using the same `nonce || ciphertext || tag` layout.
nonisolated enum VidaKeyEscrow {
    /// Named in the stored record so the parameters can be raised later
    /// without orphaning records written under the old ones.
    static let kdfIdentifier = "PBKDF2-HMAC-SHA256"

    /// OWASP's current floor for PBKDF2-HMAC-SHA256. Deliberately slow: this
    /// passphrase is the only thing between stored ciphertext and someone's
    /// symptom history, and unlike a login there is no server in the loop to
    /// rate-limit an offline guessing run.
    static let defaultIterations = 600_000

    static let saltByteCount = 16

    /// Longer than the account password rule on purpose, for the same reason
    /// the iteration count is high — an attacker with the database can guess
    /// against this offline, as fast as their hardware allows.
    static let minimumPassphraseLength = 10

    enum EscrowError: LocalizedError, Equatable {
        case passphraseTooShort
        case wrongPassphrase
        case malformedRecord
        case derivationFailed

        var errorDescription: String? {
            switch self {
            case .passphraseTooShort:
                "Use at least \(VidaKeyEscrow.minimumPassphraseLength) characters. This passphrase is what keeps your entries unreadable to everyone else."
            case .wrongPassphrase:
                "That passphrase didn't unlock your data. It's case-sensitive, and it isn't your account password."
            case .malformedRecord:
                "Your saved passphrase record couldn't be read."
            case .derivationFailed:
                "Vida couldn't prepare the passphrase on this device."
            }
        }
    }

    /// What gets stored server-side. Every field here is safe to hand to a
    /// database: without the passphrase they reveal nothing.
    struct WrappedKey: Codable, Sendable, Equatable {
        var kdf: String
        /// Base64 salt.
        var salt: String
        var iterations: Int
        /// Base64 `nonce || ciphertext || tag`, sealing the raw 32-byte key.
        var wrappedKey: String
    }

    // MARK: - Wrapping

    /// Seals this device's sync key under `passphrase`.
    ///
    /// Creates the sync key first if the member has never synced, so turning
    /// on web access can be the very first thing she does.
    static func wrapCurrentKey(
        passphrase: String,
        iterations: Int = defaultIterations
    ) throws -> WrappedKey {
        let normalized = try validated(passphrase)

        var salt = Data(count: saltByteCount)
        let generated = salt.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, saltByteCount, base)
        }
        guard generated == errSecSuccess else { throw EscrowError.derivationFailed }

        let kek = try deriveKey(passphrase: normalized, salt: salt, iterations: iterations)
        let keyMaterial = try VidaCrypto.exportKeyMaterial()

        guard let sealed = try? AES.GCM.seal(keyMaterial, using: kek),
              let combined = sealed.combined else {
            throw EscrowError.derivationFailed
        }

        return WrappedKey(
            kdf: kdfIdentifier,
            salt: salt.base64EncodedString(),
            iterations: iterations,
            wrappedKey: combined.base64EncodedString()
        )
    }

    // MARK: - Unwrapping

    /// Recovers the raw sync key from a stored record.
    ///
    /// A wrong passphrase fails the GCM tag check, so there's no separate
    /// verifier to store and no way to tell "wrong passphrase" apart from
    /// "tampered record" — which is the correct amount of information to give.
    static func unwrap(_ record: WrappedKey, passphrase: String) throws -> Data {
        let normalized = try validated(passphrase, enforcingLength: false)

        guard record.kdf == kdfIdentifier,
              record.iterations > 0,
              let salt = Data(base64Encoded: record.salt),
              let combined = Data(base64Encoded: record.wrappedKey) else {
            throw EscrowError.malformedRecord
        }

        let kek = try deriveKey(passphrase: normalized, salt: salt, iterations: record.iterations)

        guard let box = try? AES.GCM.SealedBox(combined: combined),
              let keyMaterial = try? AES.GCM.open(box, using: kek) else {
            throw EscrowError.wrongPassphrase
        }
        guard keyMaterial.count == 32 else { throw EscrowError.malformedRecord }

        return keyMaterial
    }

    /// Unwraps and installs the key into this device's Keychain — the path a
    /// second device or a reinstall takes to become able to read history.
    static func adoptKey(from record: WrappedKey, passphrase: String) throws {
        let keyMaterial = try unwrap(record, passphrase: passphrase)
        try VidaCrypto.installKeyMaterial(keyMaterial)
    }

    /// True when `passphrase` opens the record, without changing anything.
    static func verifies(_ record: WrappedKey, passphrase: String) -> Bool {
        (try? unwrap(record, passphrase: passphrase)) != nil
    }

    // MARK: - Derivation

    /// PBKDF2-HMAC-SHA256 down to 32 bytes.
    ///
    /// The passphrase is NFC-normalised first. Without it an accented
    /// character typed on a Mac and the same character typed on iOS can be
    /// different byte sequences, and the key silently wouldn't match.
    static func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let passwordData = Data(passphrase.precomposedStringWithCanonicalMapping.utf8)
        let derivedLength = 32
        var derived = Data(count: derivedLength)

        let status: Int32 = derived.withUnsafeMutableBytes { out in
            passwordData.withUnsafeBytes { password in
                salt.withUnsafeBytes { saltBytes in
                    guard let outBase = out.bindMemory(to: UInt8.self).baseAddress,
                          let passwordBase = password.bindMemory(to: CChar.self).baseAddress,
                          let saltBase = saltBytes.bindMemory(to: UInt8.self).baseAddress else {
                        return Int32(kCCParamError)
                    }
                    return CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBase, passwordData.count,
                        saltBase, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        outBase, derivedLength
                    )
                }
            }
        }

        guard status == kCCSuccess else { throw EscrowError.derivationFailed }
        return SymmetricKey(data: derived)
    }

    private static func validated(_ passphrase: String, enforcingLength: Bool = true) throws -> String {
        // Only the outer edges are trimmed. Interior spaces are part of the
        // passphrase, and a passphrase is exactly where someone should be
        // encouraged to use them.
        let trimmed = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        if enforcingLength, trimmed.count < minimumPassphraseLength {
            throw EscrowError.passphraseTooShort
        }
        return trimmed
    }
}
