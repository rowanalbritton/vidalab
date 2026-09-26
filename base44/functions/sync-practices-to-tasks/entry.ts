import { createClientFromRequest } from 'npm:@base44/sdk@0.8.48';
import { initSupabase } from "../../shared/supabaseServer.ts";

const TASKS_CONNECTOR_ID = "6ab2084927827baadedd137e";

export default async function (req: Request) {
  const base44 = createClientFromRequest(req);
  const { user, entities } = await initSupabase(req);
  if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

  let accessToken: string;
  try {
    const conn = await base44.asServiceRole.connectors.getCurrentAppUserConnection(TASKS_CONNECTOR_ID);
    accessToken = conn.accessToken;
  } catch (e) {
    return Response.json({ error: "Google Tasks not connected" }, { status: 403 });
  }

  // Fetch user's favorited health resources (practices, habits, exercises, meditations)
  const favorites = await entities.Favorite.filter({ resource_type: "health" }, "-created_date", 200);
  const practiceFavorites = favorites.filter((f: any) =>
    f.resource_category === "exercise" || f.resource_category === "meditation" ||
    f.resource_category === "habit" || f.resource_category === "supplement"
  );

  if (practiceFavorites.length === 0) {
    return Response.json({ error: "No favorited practices to sync. Favorite wellness resources in the Apothecary first." }, { status: 400 });
  }

  const headers = { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" };

  // Create a task list
  const listRes = await fetch("https://tasks.googleapis.com/tasks/v1/users/@me/lists", {
    method: "POST",
    headers,
    body: JSON.stringify({ title: "Vida Wellness Practices" }),
  });
  if (!listRes.ok) {
    console.error("sync-practices-to-tasks: list create failed", await listRes.text());
    return Response.json({ error: "Failed to create task list" }, { status: 502 });
  }
  const list = await listRes.json();
  const tasklistId = list.id;

  // Create a task for each favorited practice
  let created = 0;
  for (const fav of practiceFavorites) {
    const taskRes = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${tasklistId}/tasks`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        title: fav.resource_title,
        notes: fav.resource_subtitle || "From your Vida Lab Apothecary",
      }),
    });
    if (taskRes.ok) created++;
  }

  return Response.json({ tasklistId, created, total: practiceFavorites.length });
}