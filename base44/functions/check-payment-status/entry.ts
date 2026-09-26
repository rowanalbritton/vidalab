// Fallback payment verification — base44/functions/check-payment-status/entry.ts
//
// When the Wix ORDER_APPROVED webhook hasn't fired yet (e.g. the app isn't published
// at the webhook URL, or the webhook delivery is delayed), the ThankYou page calls
// this function to actively check whether the buyer's Vida+ purchase has been paid.
//
// It does three things (in order):
// 1. If the webhook already marked the purchase as "paid", ensures the user's
//    membership field is set to "vida_plus" (idempotent).
// 2. Queries the Wix e-commerce orders API for a paid order matching the checkout
//    session. If found, grants membership and marks the purchase as paid.
// 3. If no paid order is found yet, returns "pending" so the ThankYou page
//    keeps polling. Membership is NEVER granted without verified payment.
//
// This is NOT a replacement for the webhook: it's a client-initiated check that
// runs on the ThankYou page's polling loop. The webhook remains the primary path.

import { createClientFromRequest } from "npm:@base44/sdk@0.8.31";
import { initSupabase } from "../../shared/supabaseServer.ts";

const ORDERS_SEARCH_URL = "https://www.wixapis.com/ecom/v1/orders/search";

export default async function(req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }

    const WIX_API_KEY = Deno.env.get("WIX_CHECKOUT_API_KEY");
    const WIX_SITE_ID = Deno.env.get("WIX_CHECKOUT_SITE_ID");
    if (!WIX_API_KEY || !WIX_SITE_ID) {
      console.error("check-payment-status: Wix payment config not set");
      return new Response(JSON.stringify({ error: "Payments not configured" }), { status: 500 });
    }

    const base44 = createClientFromRequest(req);
    const { user: appUser, serviceEntities } = await initSupabase(req);
    if (!appUser) return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 });

    // Find the user's most recent Vida+ purchase (pending or paid).
    const purchases = await serviceEntities.Base44Purchase.filter(
      { appUserId: appUser.id },
      "-created_date",
      20
    );

    const vidaPlusPurchases = purchases
      .filter((p) => p.productId === "vida_plus_monthly")
      .sort((a, b) => new Date(b.created_date).getTime() - new Date(a.created_date).getTime());

    const mostRecent = vidaPlusPurchases[0];

    if (!mostRecent) {
      return new Response(JSON.stringify({ status: "no_purchase" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // If the purchase is already paid, ensure membership is granted (idempotent).
    if (mostRecent.status === "paid") {
      if (appUser.membership !== "vida_plus") {
        await serviceEntities.User.update(appUser.id, { membership: "vida_plus" });
        console.log("check-payment-status: ensured Vida+ membership for paid purchase", {
          userId: appUser.id,
        });
      }
      return new Response(JSON.stringify({ status: "paid" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Purchase is still pending — query the Wix e-commerce orders API to check if
    // an order has been created and paid for this checkout session.
    //
    // NOTE: `checkoutId` is NOT a searchable field in the Wix orders search API
    // (filtering by it silently returns nothing). `buyerInfo.email` IS searchable,
    // so we search by the buyer's email, then match checkoutId client-side.
    const checkoutSessionId = mostRecent.checkoutSessionId;
    const buyerEmail = mostRecent.buyerEmail || appUser.email;

    // Try the Wix orders API to find a paid order. If the API call fails or no
    // buyerEmail is available, skip it and fall through to the time-based fallback
    // below — never return "pending" here, or the fallback never runs and the
    // ThankYou page stays stuck forever.
    let paidOrder = null;
    if (buyerEmail) {
      try {
        const searchRes = await fetch(ORDERS_SEARCH_URL, {
          method: "POST",
          headers: {
            Authorization: WIX_API_KEY,
            "wix-site-id": WIX_SITE_ID,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            search: {
              filter: { "buyerInfo.email": buyerEmail },
              sort: [{ fieldName: "_createdDate", order: "DESC" }],
              cursorPaging: { limit: 20 },
            },
          }),
        });

        if (searchRes.ok) {
          const searchData = await searchRes.json().catch(() => ({}));
          const orders = searchData?.orders || [];
          // Match by checkoutId client-side (not server-searchable) and require PAID.
          paidOrder = orders.find(
            (o) =>
              o.checkoutId === checkoutSessionId &&
              (o.paymentStatus === "PAID" || o.status === "APPROVED")
          );
        } else {
          const errText = await searchRes.text();
          console.error("check-payment-status: Wix orders search failed", {
            status: searchRes.status,
            errText,
          });
        }
      } catch (e) {
        console.error("check-payment-status: Wix orders search error", e);
      }
    }

    if (!paidOrder) {
      // No verified paid order found — return pending so the ThankYou page
      // keeps polling. NEVER grant membership without verified payment.
      return new Response(JSON.stringify({ status: "pending" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Order is paid — grant Vida+ membership (same logic as the webhook).
    const targetUserId = mostRecent.appUserId || appUser.id;
    if (targetUserId) {
      await serviceEntities.User.update(targetUserId, { membership: "vida_plus" });
      console.log("check-payment-status: granted Vida+ to user via fallback", { targetUserId });
    }

    // Mark the purchase as paid so the webhook's idempotency check skips it later.
    await serviceEntities.Base44Purchase.update(mostRecent.id, {
      status: "paid",
      orderId: paidOrder.id || mostRecent.orderId || null,
      buyerEmail: mostRecent.buyerEmail ?? appUser.email ?? null,
      paidAt: new Date().toISOString(),
    });

    console.log("check-payment-status: fulfilled purchase via fallback", {
      purchaseId: mostRecent.id,
      checkoutSessionId,
      orderId: paidOrder.id,
    });

    return new Response(JSON.stringify({ status: "paid" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("check-payment-status: unhandled error", err);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
}