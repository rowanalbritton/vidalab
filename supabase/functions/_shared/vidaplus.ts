// Server-side Vida+ verification for app features.
//
// A member can hold Vida+ from any of three places, and any one is enough:
//
//   1. A paid website purchase in `purchases` (written only by the payments
//      webhook). Never `profiles.membership`, which members can edit.
//   2. An `entitlements` row written by the RevenueCat webhook.
//   3. RevenueCat itself, asked directly. This is the check that works before
//      the RevenueCat webhook is set up, and for App Review's sandbox
//      purchases. It uses the app's public iOS SDK key, which is already
//      shipped inside the app and is allowed to read a customer's
//      entitlements. Set it with: supabase secrets set REVENUECAT_IOS_PUBLIC_KEY=appl_...
//
// Each check fails closed: an error counts as "not a member" for that check,
// and only a positive answer from one of them grants access.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const plusProductIDs = ["vida_plus_monthly", "vida_plus_yearly", "vida_plus_family"];
const revenueCatEntitlementID = "plus";

function serviceClient() {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) throw new Error("Supabase service configuration missing.");
    return createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
}

function isFuture(value: string | null | undefined): boolean {
    if (!value) return true; // No expiry recorded means it doesn't lapse (lifetime or promo).
    const time = Date.parse(value);
    return Number.isFinite(time) && time > Date.now();
}

async function paidWebPurchase(userID: string, email?: string | null): Promise<boolean> {
    try {
        const owners = [`user_id.eq.${userID}`];
        if (email) owners.push(`buyer_email.eq.${email.toLowerCase()}`);
        const { data, error } = await serviceClient()
            .from("purchases")
            .select("id")
            .eq("status", "paid")
            .in("product_id", plusProductIDs)
            .or(owners.join(","))
            .limit(1);
        if (error) return false;
        return (data?.length ?? 0) > 0;
    } catch {
        return false;
    }
}

async function entitlementRow(userID: string): Promise<boolean> {
    try {
        const { data, error } = await serviceClient()
            .from("entitlements")
            .select("tier,status,expires_at")
            .eq("user_id", userID)
            .maybeSingle();
        if (error || !data) return false;
        const tier = String(data.tier ?? "").toLowerCase();
        const status = String(data.status ?? "").toLowerCase();
        if (!tier || tier === "free") return false;
        if (["expired", "revoked", "refunded", "free", "inactive"].includes(status)) return false;
        return isFuture(data.expires_at);
    } catch {
        return false;
    }
}

async function revenueCatEntitlement(userID: string): Promise<boolean> {
    const key = Deno.env.get("REVENUECAT_IOS_PUBLIC_KEY");
    if (!key) return false;
    try {
        const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userID)}`, {
            headers: { Authorization: `Bearer ${key}`, "X-Platform": "ios", Accept: "application/json" },
        });
        if (!response.ok) return false;
        const body = await response.json() as {
            subscriber?: { entitlements?: Record<string, { expires_date?: string | null }> };
        };
        const entitlement = body.subscriber?.entitlements?.[revenueCatEntitlementID];
        return entitlement !== undefined && isFuture(entitlement.expires_date);
    } catch {
        return false;
    }
}

/// Whether this member has Vida+ anywhere.
export async function hasVidaPlus(userID: string, email?: string | null): Promise<boolean> {
    if (await paidWebPurchase(userID, email)) return true;
    if (await entitlementRow(userID)) return true;
    return await revenueCatEntitlement(userID);
}
