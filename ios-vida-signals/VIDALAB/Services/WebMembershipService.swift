import Foundation
import Supabase

/// Checks whether the signed-in account has Vida+ from vidalab.co.
///
/// Reads `purchases`, the table only the payments webhook writes. Row-level
/// security scopes it to the member's own rows and blocks members from
/// writing it, so a paid row here is as trustworthy as it is on the website,
/// which uses the same check (`hasVidaPlus` in the site's Edge Functions).
/// `profiles.membership` is deliberately not used: members can edit it.
enum WebMembershipService {
    /// Every product ID that grants Vida+, on either surface.
    static let plusProductIDs = [
        MembershipProductID.monthly, MembershipProductID.yearly, MembershipProductID.family,
    ]

    private struct PurchaseRow: Decodable {
        let id: String
    }

    /// `true` or `false` when the lookup succeeded, `nil` when it didn't, so a
    /// dropped connection can never take away a membership.
    static func hasPaidMembership() async -> Bool? {
        do {
            let rows: [PurchaseRow] = try await vidaSupabase
                .from("purchases")
                .select("id")
                .eq("status", value: "paid")
                .in("product_id", values: plusProductIDs)
                .limit(1)
                .execute()
                .value
            return !rows.isEmpty
        } catch {
            return nil
        }
    }
}
