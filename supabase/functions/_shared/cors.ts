// Browser access for functions the website calls directly.
//
// Supabase functions live on a different origin from vidalab.co, so the
// browser sends a preflight OPTIONS request first and refuses any response
// without these headers. Auth travels as a bearer token rather than a cookie,
// so allowing any origin exposes nothing a caller couldn't already send.

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

type Handler = (req: Request) => Response | Promise<Response>;

export function withCors(handler: Handler): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

    const response = await handler(req);
    const headers = new Headers(response.headers);
    for (const [name, value] of Object.entries(corsHeaders)) headers.set(name, value);

    // `new Response(JSON.stringify(...))` is labeled text/plain, which makes
    // supabase-js hand the page a string instead of an object. Relabel any
    // plain-text body that is really JSON.
    const type = headers.get("content-type") ?? "";
    if (!type || type.startsWith("text/plain")) {
      const text = await response.text();
      try {
        JSON.parse(text);
        headers.set("content-type", "application/json");
      } catch {
        // Not JSON; leave it as it was.
      }
      return new Response(text, { status: response.status, statusText: response.statusText, headers });
    }
    return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
  };
}

/** `Deno.serve`, with the headers above on every response. */
export function serveWithCors(handler: Handler) {
  return Deno.serve(withCors(handler));
}
