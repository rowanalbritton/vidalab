import { serveWithCors } from "../_shared/cors.ts";
// Vida AI chat for the website, replacing Base44's hosted "vida" agent and the
// vida-chat-gate / vida-chat-send pair.
//
// Base44 kept conversations on its servers and streamed replies over a
// realtime subscription. Supabase has no agent runtime, so this is stateless:
// the page holds the conversation and sends it with each message, and this
// function returns Vida's next reply. No transcript is stored anywhere.
//
// Vida+ is re-checked on every call, as before, so a non-member can't spend the
// Anthropic credits by calling this directly.
//
//   POST { check: true }                      -> { allowed }
//   POST { messages: [{ role, content }, …] } -> { reply }

import type Anthropic from "@anthropic-ai/sdk";
import { initSupabase } from "../_shared/entities.ts";
import { hasVidaPlus } from "../_shared/membership.ts";
import { askChat, LLMRefusal, LLMUnavailable } from "../_shared/claude.ts";

// Carried over from base44/agents/vida.jsonc. The web-search line is gone
// because this function doesn't give Vida a search tool; explainer titles are
// passed in below instead of Base44's entity-read tool.
const CHAT_INSTRUCTIONS = `You are talking with someone in the VIDA LAB website chat. People come to you to talk through chronic illness, confusing symptoms, or general health worries. Your tone is warm, patient, validating, and personable, like a smart, caring friend who happens to know the research, never clinical or robotic.

Hard rules:
- Never diagnose, prescribe, or tell someone what condition they have or what treatment to take.
- Never contradict or replace a clinician. When something sounds urgent or severe (for example chest pain, suicidal thoughts, severe bleeding), gently and clearly urge the person to seek immediate medical care. In the US they can call or text 988 for a mental health crisis, or 911 for an emergency.
- Explain research, conditions, or terminology in plain language, and say where evidence is uncertain or still evolving.
- When one of the VIDA LAB explainers listed below fits the conversation, mention it by name.
- Keep responses conversational and not overly long. Ask follow-up questions to help the person feel heard before jumping to information.
- Always frame yourself as an educational companion for reflection, not a medical authority.`;

const MAX_TURNS = 40;
const MAX_MESSAGE_CHARS = 4000;

function json(body: unknown, status = 200) {
  return Response.json(body, { status });
}

/// Accepts only a well-formed transcript: plain-text turns that alternate,
/// start with the member, and end with the member's new message. Anything
/// else is rejected rather than repaired, because a repaired transcript would
/// no longer be what the member saw on screen.
function parseTurns(raw: unknown): Anthropic.MessageParam[] | null {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > MAX_TURNS) return null;

  const turns: Anthropic.MessageParam[] = [];
  for (const [index, item] of raw.entries()) {
    const role = item?.role;
    const content = typeof item?.content === "string" ? item.content.trim() : "";
    const expected = index % 2 === 0 ? "user" : "assistant";
    if (role !== expected || !content || content.length > MAX_MESSAGE_CHARS) return null;
    turns.push({ role, content });
  }
  return turns[turns.length - 1].role === "user" ? turns : null;
}

async function explainerContext(serviceEntities: any): Promise<string> {
  try {
    const explainers = await serviceEntities.Explainer.list("-created_date", 60);
    const titles = explainers
      .filter((e: any) => e.is_public !== false && e.title)
      .map((e: any) => `- ${e.title}`);
    return titles.length ? `VIDA LAB explainers you can point to:\n${titles.join("\n")}` : "";
  } catch (e) {
    console.error("vida-chat: could not load explainers", e);
    return "";
  }
}

serveWithCors(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { body, user, serviceEntities } = await initSupabase(req);
    if (!user) return json({ allowed: false, error: "Unauthorized" }, 401);

    const allowed = await hasVidaPlus(user.id, user.email);
    if (body?.check === true) return json({ allowed });
    if (!allowed) return json({ error: "Vida+ required" }, 403);

    const turns = parseTurns(body?.messages);
    if (!turns) {
      return json({ error: "That conversation couldn't be read. Refresh the page and try again." }, 400);
    }

    const context = await explainerContext(serviceEntities);
    const reply = await askChat({
      turns,
      system: context ? `${CHAT_INSTRUCTIONS}\n\n${context}` : CHAT_INSTRUCTIONS,
    });
    return json({ reply });
  } catch (error) {
    if (error instanceof LLMRefusal) {
      return json({
        reply: "I can't help with that one here. If you're worried about your health right now, please reach out to a doctor, or call or text 988 if you're in crisis.",
      });
    }
    if (error instanceof LLMUnavailable) {
      return json({ error: "Vida couldn't answer just now. Please try again in a moment." }, error.retryable ? 503 : 500);
    }
    console.error("vida-chat: unhandled error", error);
    return json({ error: "Something went wrong. Please try again." }, 500);
  }
});
