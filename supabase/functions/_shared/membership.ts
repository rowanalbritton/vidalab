// Server-side Vida+ verification.
//
// Reads `purchases`, which only the payments webhook can write. It deliberately
// does **not** trust `profiles.membership`: that column is client-writable, so
// anyone could grant themselves Vida+ with a profile update.
//
// Ported from base44/shared/membership.ts. Same guarantee, but querying
// Supabase directly rather than through Base44's entity wrapper, so it works
// unchanged in a Supabase Edge Function.

import { createClient } from "@supabase/supabase-js";

const RAW_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_URL = RAW_URL.replace(/\/rest\/v1\/?$/, "").replace(/\/$/, "");

/// Product IDs that grant Vida+. Kept as a list because the iOS app sells
/// monthly, yearly, and family tiers, and a member who bought any of them is a
/// member — matching only the monthly ID (as the Base44 version did) locks out
/// yearly and family subscribers.
const plusProductIDs = [
    "vida_plus_monthly",
    "vida_plus_yearly",
    "vida_plus_family"
];

export function serviceClient() {
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!key) throw new Error("SUPABASE_SERVICE_ROLE_KEY is not set.");
    return createClient(SUPABASE_URL, key, {
        auth: { autoRefreshToken: false, persistSession: false }
    });
}

/// Whether this member has a paid Vida+ purchase, by account or by the email
/// they checked out with.
export async function hasVidaPlus(userID: string, userEmail?: string | null): Promise<boolean> {
    const server = serviceClient();

    // Email is matched as well as user ID because the web checkout can complete
    // before the buyer has an account, in which case the purchase row carries
    // only their email.
    const owners = [`user_id.eq.${userID}`];
    if (userEmail) owners.push(`buyer_email.eq.${userEmail.toLowerCase()}`);

    const { data, error } = await server
        .from("purchases")
        .select("id")
        .eq("status", "paid")
        .in("product_id", plusProductIDs)
        .or(owners.join(","))
        .limit(1);

    if (error) {
        // Fail closed. A membership check that errors open would hand paid
        // features to everyone the moment the table or its policy changed.
        console.error("membership check failed", error.code);
        return false;
    }
    return (data?.length ?? 0) > 0;
}
