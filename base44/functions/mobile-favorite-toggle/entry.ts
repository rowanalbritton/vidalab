import { createClientFromRequest } from 'npm:@base44/sdk@0.8.44';
import { initSupabase } from "../../shared/supabaseServer.ts";

// Mobile Favorite Toggle — adds or removes a favorite in one call.
// Returns { favorited: true/false } so the iOS app can update the heart icon.
// The favorite is stored in the shared database, so it syncs to the web instantly.
export default async function(req) {
  try {
    const base44 = createClientFromRequest(req);
    const { body, user, entities } = await initSupabase(req);
    if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 });

    const { resource_id, resource_title, resource_category } = body;

    if (!resource_id || !resource_title) {
      return Response.json(
        { error: 'Missing required fields: resource_id, resource_title' },
        { status: 400 }
      );
    }

    // Check if already favorited by this user
    const existing = await entities.Favorite.filter({ resource_id }, null, 1);

    if (existing && existing.length > 0) {
      // Already favorited — remove it
      await entities.Favorite.delete(existing[0].id);
      return Response.json({ favorited: false, resource_id });
    } else {
      // Not favorited — add it
      await entities.Favorite.create({
        resource_id,
        resource_title,
        resource_category: resource_category || '',
      });
      return Response.json({ favorited: true, resource_id });
    }
  } catch (error) {
    console.error('mobile-favorite-toggle error:', error?.message || error);
    return Response.json({ error: error?.message || 'Internal error' }, { status: 500 });
  }
}