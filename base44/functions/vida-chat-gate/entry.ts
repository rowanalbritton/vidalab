// Server-side gate for the Vida AI chat agent.
// Verifies the caller has an active Vida+ subscription (paid Base44Purchase)
// and creates the conversation server-side — the client never calls
// base44.agents.createConversation directly, so a non-subscriber cannot
// bypass this gate by scripting the SDK from the browser console.
//
// Returns the full conversation object when allowed; 403 otherwise.

import { createClientFromRequest } from "npm:@base44/sdk@0.8.48";
import { hasVidaPlus } from "../../shared/membership.ts";
import { initSupabase } from "../../shared/supabaseServer.ts";

export default async function (req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return Response.json({ error: "Method not allowed" }, { status: 405 });
    }

    const base44 = createClientFromRequest(req);
    const { user, serviceEntities } = await initSupabase(req);
    if (!user) return Response.json({ allowed: false }, { status: 401 });

    const isVidaPlus = await hasVidaPlus(serviceEntities, user.id, user.email);
    if (!isVidaPlus) {
      return Response.json({ allowed: false }, { status: 403 });
    }

    // Create the conversation server-side so the client never has
    // direct access to the un-gated createConversation endpoint.
    const conversation = await base44.agents.createConversation({
      agent_name: "vida",
      metadata: { name: "Chat with Vida" },
    });

    return Response.json({ allowed: true, conversation });
  } catch (error) {
    console.error("vida-chat-gate: unhandled error", error);
    return Response.json({ allowed: false, error: error.message }, { status: 500 });
  }
}