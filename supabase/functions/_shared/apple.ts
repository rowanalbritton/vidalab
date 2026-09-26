// Sign in with Apple server calls: exchanging the one-time authorization code
// for a refresh token, and revoking that token when an account is deleted.
//
// Both need a client secret: a short-lived ES256 JWT signed with a Sign in
// with Apple key from the Apple Developer account (Certificates, Identifiers
// & Profiles > Keys). Required secrets:
//   APPLE_TEAM_ID      e.g. FQF67NVP7H
//   APPLE_KEY_ID       the key's 10-character ID
//   APPLE_PRIVATE_KEY  the .p8 file's contents, including the BEGIN/END lines
//   APPLE_CLIENT_ID    optional, defaults to the app's bundle ID
// Until they're set, `isAppleConfigured()` is false and callers skip Apple.

import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

const APPLE_AUTH = "https://appleid.apple.com";

function config() {
    return {
        teamID: Deno.env.get("APPLE_TEAM_ID") ?? "",
        keyID: Deno.env.get("APPLE_KEY_ID") ?? "",
        // Secrets set from a shell often arrive with literal "\n" sequences.
        privateKey: (Deno.env.get("APPLE_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n"),
        clientID: Deno.env.get("APPLE_CLIENT_ID") ?? "app.vidalab",
    };
}

export function isAppleConfigured(): boolean {
    const { teamID, keyID, privateKey } = config();
    return Boolean(teamID && keyID && privateKey);
}

async function clientSecret(): Promise<string> {
    const { teamID, keyID, privateKey, clientID } = config();
    const key = await importPKCS8(privateKey, "ES256");
    return await new SignJWT({})
        .setProtectedHeader({ alg: "ES256", kid: keyID })
        .setIssuer(teamID)
        .setIssuedAt()
        .setExpirationTime("5m")
        .setAudience(APPLE_AUTH)
        .setSubject(clientID)
        .sign(key);
}

async function post(path: string, fields: Record<string, string>): Promise<Response> {
    return await fetch(`${APPLE_AUTH}${path}`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams(fields),
    });
}

/// Exchanges the authorization code from a native sign-in for a refresh
/// token. The code is single-use and expires after five minutes, so this runs
/// right after sign-in. Returns null when Apple rejects the code.
export async function exchangeAuthorizationCode(code: string): Promise<string | null> {
    const response = await post("/auth/token", {
        client_id: config().clientID,
        client_secret: await clientSecret(),
        code,
        grant_type: "authorization_code",
    });
    if (!response.ok) {
        // Apple's error body names the reason (invalid_grant, invalid_client)
        // and never echoes the code, so it's safe to log.
        console.error("apple token exchange failed", response.status, await response.text());
        return null;
    }
    const body = await response.json() as { refresh_token?: string };
    return body.refresh_token ?? null;
}

/// Revokes a refresh token. Apple answers 200 for a token that's already
/// revoked or expired, so a retry is harmless.
export async function revokeRefreshToken(token: string): Promise<boolean> {
    const response = await post("/auth/revoke", {
        client_id: config().clientID,
        client_secret: await clientSecret(),
        token,
        token_type_hint: "refresh_token",
    });
    if (!response.ok) {
        console.error("apple token revoke failed", response.status, await response.text());
    }
    return response.ok;
}
