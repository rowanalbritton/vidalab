import { serveWithCors } from "../_shared/cors.ts";
import { initSupabase } from "../_shared/entities.ts";

// Flags a community post or reply for moderator review.
// Any authenticated user can flag; only admins can hide/delete (via RLS).
serveWithCors(async (req: Request) => {
  try {
    const { body, user, serviceEntities } = await initSupabase(req);
    if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

    const { type, id } = body;
    if (!type || !id) {
      return Response.json({ error: "Type and id required" }, { status: 400 });
    }
    if (type !== "post" && type !== "reply") {
      return Response.json({ error: "Invalid type" }, { status: 400 });
    }

    if (type === "post") {
      await serviceEntities.CommunityPost.update(id, { flagged: true });
    } else {
      await serviceEntities.CommunityReply.update(id, { flagged: true });
    }

    return Response.json({ ok: true });
  } catch (error) {
    console.error("flag-community-content error:", error);
    return Response.json({ error: error instanceof Error ? error.message : String(error) }, { status: 500 });
  }
});
