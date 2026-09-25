import CryptoKit
import Foundation

/// Stable server key for one signal in one half of one local day.
///
/// A member can edit the same morning energy answer from two devices. Using a
/// deterministic ID, rather than a device-generated UUID, lets the server
/// compare those edits as one event and keep the newest one.
nonisolated enum CheckInSyncEventID {
    static func make(
        userID: String,
        localDate: Date,
        category: SignalCategory,
        period: CheckInPeriod
    ) -> UUID {
        let material = "vida-checkin-v1|\(userID.lowercased())|\(VidaDateKey.string(from: localDate))|\(category.rawValue)|\(period.rawValue)"
        let digest = SHA256.hash(data: Data(material.utf8))
        var bytes = Array(digest.prefix(16))
        // RFC 4122 variant and version-5 layout. The digest is SHA-256 rather
        // than SHA-1, but this preserves UUID interoperability and stability.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
