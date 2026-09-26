// Server-side relay for user messages to the Vida AI chat agent.
// Verifies Vida+ membership before adding a message to the conversation,
// so a non-subscriber cannot call base44.agents.addMessage directly from
// the browser to consume the app owner's LLM credits without paying.

import { createClientFromRequest } from "npm:@base44/sdk@0.8.48";
import { hasVidaPlus } from "../../shared/membership.ts";
import { initSupabase } from "../../shared/supabaseServer.ts";

export default async function (req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return Response.json({ error: "Method not allowed" }, { status: 405 });
    }

    const base44 = createClientFromRequest(req);
    const { body, user, serviceEntities } = await initSupabase(req);
    if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

    const isVidaPlus = await hasVidaPlus(serviceEntities, user.id, user.email);
    if (!isVidaPlus) {
      return Response.json({ error: "Vida+ required" }, { status: 403 });
    }

    const { conversationId, content } = body;
    if (!conversationId || !content || typeof content !== "string") {
      return Response.json({ error: "conversationId and content required" }, { status: 400 });
    }

    // addMessage requires the full conversation object; fetch it server-side
    // so the client never passes a forgeable object — only the conversationId.
    const conversation = await base44.agents.getConversation(conversationId);
    if (!conversation) {
      return Response.json({ error: "Conversation not found" }, { status: 404 });
    }

    await base44.agents.addMessage(conversation, { role: "user", content });

    return Response.json({ ok: true });
  } catch (error) {
    console.error("vida-chat-send: unhandled error", error);
    return Response.json({ error: error.message }, { status: 500 });
  }
}