// Server-side Vida+ membership verification.
// Does NOT trust the client-writable User.membership field — instead verifies
// a paid Base44Purchase record, which only the JWT-verified webhook can set.
//
// Works with both Base44's db.entities and Supabase's serviceEntities —
// both expose the same .Base44Purchase.filter() API shape.

export async function hasVidaPlus(
  entities: any,
  userId: string,
  userEmail?: string
): Promise<boolean> {
  // Check for a paid purchase by appUserId (signed-in buyer)
  try {
    const byId = await entities.Base44Purchase.filter(
      { appUserId: userId, productId: "vida_plus_monthly", status: "paid" },
      "-created_date",
      5
    );
    if (byId && byId.length > 0) return true;
  } catch (e) {
    console.error("membership: error checking purchases by userId", e);
  }

  // Check for a paid purchase by buyerEmail (anonymous buyer matched by email)
  if (userEmail) {
    try {
      const byEmail = await entities.Base44Purchase.filter(
        { buyerEmail: userEmail, productId: "vida_plus_monthly", status: "paid" },
        "-created_date",
        5
      );
      if (byEmail && byEmail.length > 0) return true;
    } catch (e) {
      console.error("membership: error checking purchases by email", e);
    }
  }

  return false;
}