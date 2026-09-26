// The one place Vida sends email.
//
// Replaces Base44's `integrations.Core.SendEmail`, keeping the same call shape
// (`to`, `subject`, `html`, optional `fromName`) so the newsletter, appointment
// reminder, and doctor-snapshot functions port across without rewriting their
// HTML builders.
//
// Required secrets:
//   RESEND_API_KEY   — from resend.com
//   VIDA_FROM_EMAIL  — e.g. "Vida Lab <hello@vidalab.co>". The domain must be
//                      verified in Resend or every send is rejected.

const resendEndpoint = "https://api.resend.com/emails";

export class EmailUnavailable extends Error {
    constructor(message: string, readonly retryable: boolean) {
        super(message);
        this.name = "EmailUnavailable";
    }
}

interface SendOptions {
    to: string;
    subject: string;
    html: string;
    /// Overrides the display name on the configured from-address. The address
    /// itself can't be overridden — it has to stay on the verified domain.
    fromName?: string;
    replyTo?: string;
}

function fromAddress(fromName?: string): string {
    const configured = Deno.env.get("VIDA_FROM_EMAIL");
    if (!configured) {
        throw new EmailUnavailable("VIDA_FROM_EMAIL is not set.", false);
    }
    if (!fromName) return configured;

    // Swap the display name, keep the address. Accepts both "Name <a@b>" and a
    // bare "a@b" as the configured value.
    const bracketed = configured.match(/<([^>]+)>/);
    const address = bracketed ? bracketed[1] : configured;
    return `${fromName} <${address}>`;
}

/// Sends one email. Throws `EmailUnavailable` rather than returning a status,
/// so a caller looping over recipients has to decide explicitly whether one
/// failure should stop the batch.
export async function sendEmail(options: SendOptions): Promise<string> {
    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) {
        throw new EmailUnavailable("RESEND_API_KEY is not set.", false);
    }

    let response: Response;
    try {
        response = await fetch(resendEndpoint, {
            method: "POST",
            headers: {
                authorization: `Bearer ${apiKey}`,
                "content-type": "application/json"
            },
            body: JSON.stringify({
                from: fromAddress(options.fromName),
                to: [options.to],
                subject: options.subject,
                html: options.html,
                ...(options.replyTo ? { reply_to: options.replyTo } : {})
            })
        });
    } catch {
        throw new EmailUnavailable("Could not reach the email provider.", true);
    }

    if (!response.ok) {
        // Deliberately not echoed to the caller: Resend's error body can quote
        // the recipient address, and these are health-related sends.
        const detail = await response.text();
        console.error("resend rejected send", response.status, detail.slice(0, 200));
        // 429 and 5xx are worth retrying; a 4xx is a bad address or an
        // unverified domain, and will fail identically next time.
        const retryable = response.status === 429 || response.status >= 500;
        throw new EmailUnavailable("That email could not be sent.", retryable);
    }

    const body = await response.json() as { id?: string };
    return body.id ?? "";
}
