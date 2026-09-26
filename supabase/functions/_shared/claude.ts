// The one place Vida talks to a language model.
//
// Replaces Base44's `integrations.Core.InvokeLLM`. Every AI feature on the site
// goes through here so that three things are true in one place rather than
// repeated in eight prompts:
//
//   1. The educational framing is not optional. `HEALTH_SYSTEM_PROMPT` is
//      prepended to every call. Base44 put that guidance in each function's
//      prompt string, which meant a new feature could quietly ship without it.
//   2. A refusal is a distinct outcome, not an empty answer. Claude can decline
//      a request and still return HTTP 200, so callers get `LLMRefusal` rather
//      than a blank string they might render as an answer.
//   3. A truncated structured response fails loudly instead of yielding
//      half-parsed JSON.
//
// Required secret: ANTHROPIC_API_KEY.

import Anthropic from "@anthropic-ai/sdk";

/// Claude Sonnet 5 — chosen for cost at the volume a public site sees. Swap
/// this single constant to `claude-opus-5` if answer quality on the harder
/// pattern-analysis features matters more than per-call price.
export const VIDA_MODEL = "claude-sonnet-5";

/// Prepended to every request. Read this as the product's medical-safety
/// boundary expressed once, in code, rather than as prose each caller
/// remembers to include.
export const HEALTH_SYSTEM_PROMPT = `You are Vida, the health companion for VIDA LAB.

VIDA LAB helps people find patterns in their own health data. It is educational. It does not diagnose.

Rules that are not negotiable:
- Never state or imply that someone has a condition. Say "worth exploring", "patterns consistent with", "worth raising with a doctor".
- Never give a dose, a drug recommendation, or a treatment plan.
- Reference the person's own logged data when you explain something, rather than generalising.
- Name red-flag symptoms that deserve prompt medical attention when they are relevant, plainly and without alarm.
- Be warm and direct. The people reading this have often been dismissed by clinicians, so condescension and hedging both land badly.
- If the data is too thin or too vague to say anything useful, say that instead of inventing a pattern.`;

/// Claude declined the request. A real outcome to handle, not a failure to
/// retry: the same prompt will be declined again.
export class LLMRefusal extends Error {
    constructor(readonly category: string | null) {
        super("The model declined to answer this request.");
        this.name = "LLMRefusal";
    }
}

/// Anything else — no key configured, rate limited, upstream error, or a
/// response too truncated to use.
export class LLMUnavailable extends Error {
    constructor(message: string, readonly retryable: boolean) {
        super(message);
        this.name = "LLMUnavailable";
    }
}

let cached: Anthropic | null = null;

function client(): Anthropic {
    if (cached) return cached;
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
        throw new LLMUnavailable("ANTHROPIC_API_KEY is not set.", false);
    }
    cached = new Anthropic({ apiKey });
    return cached;
}

type Effort = "low" | "medium" | "high" | "xhigh" | "max";

interface AskOptions {
    prompt: string;
    /// Appended after the health preamble, for feature-specific instructions.
    system?: string;
    maxTokens?: number;
    /// Defaults to "medium". Raise for the pattern-analysis features, lower for
    /// short lookups.
    effort?: Effort;
}

/// Recursively seals every object in a JSON Schema with
/// `additionalProperties: false`.
///
/// Structured outputs require this on every object node and reject the schema
/// otherwise. The Base44 schemas were written without it, so sealing here means
/// those schemas can be carried over unchanged instead of hand-edited — and a
/// new one can't fail for a reason that has nothing to do with its content.
export function sealSchema(schema: unknown): unknown {
    if (Array.isArray(schema)) return schema.map(sealSchema);
    if (!schema || typeof schema !== "object") return schema;

    const node = schema as Record<string, unknown>;
    const sealed: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(node)) {
        sealed[key] = sealSchema(value);
    }
    if (sealed.type === "object" && sealed.additionalProperties === undefined) {
        sealed.additionalProperties = false;
    }
    return sealed;
}

function firstText(message: Anthropic.Message): string {
    for (const block of message.content) {
        if (block.type === "text") return block.text;
    }
    return "";
}

function translate(error: unknown): LLMUnavailable {
    if (error instanceof LLMRefusal || error instanceof LLMUnavailable) throw error;

    // Most specific first. The distinction that matters to the caller is
    // whether retrying could plausibly work.
    if (error instanceof Anthropic.RateLimitError) {
        return new LLMUnavailable("Vida is busy right now. Try again shortly.", true);
    }
    if (error instanceof Anthropic.APIConnectionError) {
        return new LLMUnavailable("Could not reach the model.", true);
    }
    if (error instanceof Anthropic.APIError) {
        const retryable = typeof error.status === "number" && error.status >= 500;
        // Logged, not returned: an upstream message can quote the prompt, and
        // these prompts contain the member's own health data.
        console.error("claude request failed", error.status, error.name);
        return new LLMUnavailable("Vida could not generate an answer.", retryable);
    }
    console.error("claude request failed with an unrecognised error");
    return new LLMUnavailable("Vida could not generate an answer.", false);
}

/// Plain prose answer.
export async function askText(options: AskOptions): Promise<string> {
    const { prompt, system, maxTokens = 4096, effort = "medium" } = options;

    let message: Anthropic.Message;
    try {
        message = await client().messages.create({
            model: VIDA_MODEL,
            max_tokens: maxTokens,
            system: system ? `${HEALTH_SYSTEM_PROMPT}\n\n${system}` : HEALTH_SYSTEM_PROMPT,
            output_config: { effort },
            messages: [{ role: "user", content: prompt }],
        });
    } catch (error) {
        throw translate(error);
    }

    // Before reading content: a refusal returns 200 with empty or partial
    // content, so indexing straight into it would render nothing as an answer.
    if (message.stop_reason === "refusal") {
        throw new LLMRefusal(message.stop_details?.category ?? null);
    }

    const text = firstText(message).trim();
    if (!text) {
        throw new LLMUnavailable("The model returned an empty answer.", true);
    }
    return text;
}

/// Structured answer validated against `schema`. The direct replacement for
/// Base44's `InvokeLLM({ prompt, response_json_schema })`.
export async function askJSON<T>(options: AskOptions & { schema: unknown }): Promise<T> {
    const { prompt, system, schema, maxTokens = 8192, effort = "medium" } = options;

    let message: Anthropic.Message;
    try {
        message = await client().messages.create({
            model: VIDA_MODEL,
            max_tokens: maxTokens,
            system: system ? `${HEALTH_SYSTEM_PROMPT}\n\n${system}` : HEALTH_SYSTEM_PROMPT,
            output_config: {
                effort,
                // Cast: `sealSchema` is deliberately schema-shape-agnostic so
                // any Base44 schema can be passed through unedited.
                format: {
                    type: "json_schema",
                    schema: sealSchema(schema) as Record<string, unknown>,
                },
            },
            messages: [{ role: "user", content: prompt }],
        });
    } catch (error) {
        throw translate(error);
    }

    if (message.stop_reason === "refusal") {
        throw new LLMRefusal(message.stop_details?.category ?? null);
    }
    // Truncation is the one failure that would otherwise look like success:
    // the JSON is cut mid-structure and `JSON.parse` throws somewhere far from
    // the cause. Retryable, because a larger budget may fit.
    if (message.stop_reason === "max_tokens") {
        throw new LLMUnavailable("The answer was longer than the token budget.", true);
    }

    const text = firstText(message);
    try {
        return JSON.parse(text) as T;
    } catch {
        throw new LLMUnavailable("The model returned malformed JSON.", true);
    }
}

/// One reply in an ongoing conversation. The API is stateless, so the caller
/// sends the whole history each time: alternating turns, starting and ending
/// with the member's message.
///
/// Replaces Base44's hosted agent conversations. Nothing is stored server-side;
/// the transcript lives only in the member's browser tab.
export async function askChat(options: {
    turns: Anthropic.MessageParam[];
    system?: string;
    maxTokens?: number;
    effort?: Effort;
}): Promise<string> {
    const { turns, system, maxTokens = 4096, effort = "medium" } = options;

    let message: Anthropic.Message;
    try {
        message = await client().messages.create({
            model: VIDA_MODEL,
            max_tokens: maxTokens,
            system: system ? `${HEALTH_SYSTEM_PROMPT}\n\n${system}` : HEALTH_SYSTEM_PROMPT,
            output_config: { effort },
            messages: turns,
        });
    } catch (error) {
        throw translate(error);
    }

    if (message.stop_reason === "refusal") {
        throw new LLMRefusal(message.stop_details?.category ?? null);
    }

    const text = firstText(message).trim();
    if (!text) {
        throw new LLMUnavailable("The model returned an empty answer.", true);
    }
    return text;
}
