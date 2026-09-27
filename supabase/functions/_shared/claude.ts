// The one place the app's Edge Functions call Claude.
//
// Required secret: ANTHROPIC_API_KEY.
//
// Every request carries the health system prompt below, so the educational
// framing that keeps these features on the right side of App Review 1.4.1
// can't be dropped by editing one feature's prompt.

import Anthropic from "npm:@anthropic-ai/sdk@^0.128.0";

export const VIDA_MODEL = "claude-opus-5";

export const HEALTH_SYSTEM_PROMPT = `You are Vida, the health companion inside the VIDA LAB app.

VIDA LAB helps people find patterns in their own health tracking. It is educational. It does not diagnose.

Rules that are not negotiable:
- Never state or imply that someone has a condition. Say "worth exploring", "patterns consistent with", "worth raising with a doctor".
- Never give a dose, a drug recommendation, or a treatment plan.
- Reference the person's own logged data when you explain something, rather than generalizing.
- Name red-flag symptoms that deserve prompt medical attention when they are relevant, plainly and without alarm.
- Be warm and direct. The people reading this have often been dismissed by clinicians, so condescension and hedging both land badly.
- If the data is too thin or too vague to say anything useful, say that instead of inventing a pattern.
- Write in plain sentences. Do not use em dashes.`;

/// The model declined the request. Retrying won't change that.
export class LLMRefusal extends Error {
    constructor(readonly category: string | null) {
        super("The model declined to answer this request.");
        this.name = "LLMRefusal";
    }
}

/// The request didn't produce a usable answer. `retryable` says whether the
/// same request could reasonably succeed a moment later.
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
    if (!apiKey) throw new LLMUnavailable("ANTHROPIC_API_KEY is not set.", false);
    cached = new Anthropic({ apiKey });
    return cached;
}

/// Structured outputs require `additionalProperties: false` on every object,
/// and every property listed in `required`. Sealing here keeps each feature's
/// schema readable.
export function sealSchema(schema: unknown): unknown {
    if (Array.isArray(schema)) return schema.map(sealSchema);
    if (!schema || typeof schema !== "object") return schema;
    const sealed: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(schema as Record<string, unknown>)) {
        sealed[key] = sealSchema(value);
    }
    if (sealed.type === "object") {
        if (sealed.additionalProperties === undefined) sealed.additionalProperties = false;
        const properties = sealed.properties as Record<string, unknown> | undefined;
        if (properties) sealed.required = Object.keys(properties);
    }
    return sealed;
}

function translate(error: unknown): Error {
    if (error instanceof LLMRefusal || error instanceof LLMUnavailable) return error;
    if (error instanceof Anthropic.APIConnectionError) {
        return new LLMUnavailable("Could not reach the model.", true);
    }
    if (error instanceof Anthropic.RateLimitError) {
        return new LLMUnavailable("Vida is busy right now.", true);
    }
    if (error instanceof Anthropic.APIError) {
        const retryable = typeof error.status === "number" && error.status >= 500;
        // Logged, not returned: an upstream message can quote the prompt, and
        // these prompts contain the member's own health data.
        console.error("claude request failed", error.status, error.name);
        return new LLMUnavailable("Vida could not generate an answer.", retryable);
    }
    console.error("claude request failed with an unrecognized error");
    return new LLMUnavailable("Vida could not generate an answer.", false);
}

type Effort = "low" | "medium" | "high" | "xhigh" | "max";

/// A structured answer validated against `schema`.
export async function askJSON<T>(options: {
    prompt: string;
    system: string;
    schema: unknown;
    effort?: Effort;
    maxTokens?: number;
}): Promise<T> {
    const { prompt, system, schema, effort = "medium", maxTokens = 16000 } = options;

    let message: Anthropic.Beta.BetaMessage;
    try {
        message = await client().beta.messages.create({
            model: VIDA_MODEL,
            max_tokens: maxTokens,
            // If Claude Opus 5's classifiers decline, the API re-runs the same
            // request on Anthropic's recommended fallback for that category.
            betas: ["server-side-fallback-2026-07-01"],
            // Cast: the "default" scalar form may be newer than this SDK's
            // type for `fallbacks`, which describes the array form.
            ...({ fallbacks: "default" } as Record<string, unknown>),
            system: `${HEALTH_SYSTEM_PROMPT}\n\n${system}`,
            output_config: {
                effort,
                format: { type: "json_schema", schema: sealSchema(schema) as Record<string, unknown> },
            },
            messages: [{ role: "user", content: prompt }],
        });
    } catch (error) {
        throw translate(error);
    }

    // Before reading content: a refusal returns 200 with empty or partial
    // content, so indexing into it would render nothing as an answer.
    if (message.stop_reason === "refusal") {
        const details = (message as unknown as { stop_details?: { category?: string | null } }).stop_details;
        throw new LLMRefusal(details?.category ?? null);
    }
    // Truncated JSON looks like success until JSON.parse fails far from here.
    if (message.stop_reason === "max_tokens") {
        throw new LLMUnavailable("The answer was longer than the token budget.", true);
    }

    const text = message.content.find((block) => block.type === "text");
    if (!text || text.type !== "text") {
        throw new LLMUnavailable("The model returned no answer.", true);
    }
    try {
        return JSON.parse(text.text) as T;
    } catch {
        throw new LLMUnavailable("The model returned malformed JSON.", true);
    }
}
