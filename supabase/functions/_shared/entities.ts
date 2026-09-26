// Server-side Supabase helper for Base44 backend functions.
// Replaces base44.auth.me() and base44.entities.* with Supabase equivalents.
//
// Usage in a backend function:
//   import { initSupabase } from "../shared/supabaseServer.ts";
//   export default async function (req: Request) {
//     const base44 = createClientFromRequest(req); // keep for connectors/integrations
//     const { body, user, entities, serviceEntities } = await initSupabase(req);
//     if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });
//     const checkins = await entities.DailyCheckin.list("-checkin_date", 500);
//     ...
//   }

import { createClient } from "@supabase/supabase-js";

// Strip /rest/v1/ suffix if present — the Base44 secret may include the REST endpoint path,
// but the Supabase SDK expects just the base project URL (e.g. https://xxx.supabase.co).
const RAW_SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_URL = RAW_SUPABASE_URL.replace(/\/rest\/v1\/?$/, "").replace(/\/$/, "");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ===== Table + field maps (mirror frontend entities.js) =====

const TABLE_MAP: Record<string, string> = {
  DailyCheckin: "daily_checkins",
  Experiment: "experiments",
  ExperimentLog: "experiment_logs",
  Favorite: "favorites",
  Treatment: "treatments",
  Appointment: "appointments",
  CommunityPost: "community_posts",
  CommunityReply: "community_replies",
  Doctor: "doctors",
  HealthResource: "health_resources",
  DiseaseReport: "disease_reports",
  Explainer: "explainers",
  SubstackArticle: "substack_articles",
  ResearchPaper: "research_papers",
  NewsletterSignup: "newsletter_signups",
  Base44Purchase: "purchases",
  User: "profiles",
};

const FIELD_MAPS: Record<string, Record<string, string>> = {
  DailyCheckin: { created_by_id: "user_id" },
  Experiment: { created_by_id: "user_id" },
  ExperimentLog: { created_by_id: "user_id" },
  Favorite: { created_by_id: "user_id" },
  Treatment: { created_by_id: "user_id" },
  Appointment: { created_by_id: "user_id" },
  // Canonical DB columns are body / created_at / author_id; these map back to
  // the names the site's components already read.
  CommunityPost: {
    created_by_id: "author_id",
    content: "body",
    created_date: "created_at",
    updated_date: "updated_at",
  },
  CommunityReply: {
    created_by_id: "author_id",
    content: "body",
    created_date: "created_at",
    updated_date: "updated_at",
  },
  Base44Purchase: {
    created_by_id: "user_id",
    checkoutSessionId: "checkout_session_id",
    orderId: "order_id",
    appUserId: "user_id",
    buyerEmail: "buyer_email",
    productId: "product_id",
    productName: "product_name",
    subscriptionId: "subscription_id",
    paidAt: "paid_at",
    canceledAt: "canceled_at",
  },
};

const SELECT_COLUMNS: Record<string, string> = {
  // Canonical community column names — see
  // supabase/migrations/20260924140000_reconcile_community_schema.sql.
  // `author_id` is deliberately absent: it is withheld by column grant, and
  // a bare select(*) fails that grant.
  CommunityPost: "id,title,body,category,display_name,status,flagged,created_at,updated_at",
  CommunityReply: "id,post_id,body,display_name,status,flagged,created_at,updated_at",
};

// ===== Query translator (ported from frontend queryTranslator.js) =====

const OPERATOR_MAP: Record<string, string> = {
  $eq: "eq", $ne: "neq", $gt: "gt", $gte: "gte", $lt: "lt", $lte: "lte",
  $in: "in", $like: "like", $ilike: "ilike",
};

function applyCondition(query: any, field: string, condition: any, fieldMap: Record<string, string>) {
  const supaField = fieldMap[field] || field;
  if (condition === null || condition === undefined) return query.is(supaField, null);
  if (Array.isArray(condition)) return query.in(supaField, condition);
  if (typeof condition !== "object") return query.eq(supaField, condition);
  for (const [op, val] of Object.entries(condition)) {
    const method = OPERATOR_MAP[op];
    if (method) query = query[method](supaField, val);
    else if (op === "$nin") query = query.not(supaField, "in", val);
    else if (op === "$regex") query = query.ilike(supaField, `%${val}%`);
  }
  return query;
}

function buildOrString(conditions: any[], fieldMap: Record<string, string>) {
  return conditions.map((cond) => {
    const parts: string[] = [];
    for (const [field, value] of Object.entries(cond)) {
      const supaField = fieldMap[field] || field;
      if (value !== null && typeof value === "object" && !Array.isArray(value)) {
        for (const [op, val] of Object.entries(value as any)) {
          const method = OPERATOR_MAP[op] || "eq";
          parts.push(`${supaField}.${method}.${val}`);
        }
      } else {
        parts.push(`${supaField}.eq.${value}`);
      }
    }
    return parts.join(",");
  }).join(",");
}

function applyQuery(query: any, queryObj: any, fieldMap: Record<string, string> = {}) {
  if (!queryObj || typeof queryObj !== "object") return query;
  for (const [key, value] of Object.entries(queryObj)) {
    if (key === "$or") query = query.or(buildOrString(value as any[], fieldMap));
    else if (key === "$and") {
      for (const cond of value as any[]) {
        for (const [f, v] of Object.entries(cond)) query = applyCondition(query, f, v, fieldMap);
      }
    } else query = applyCondition(query, key, value, fieldMap);
  }
  return query;
}

// ===== Entity factory =====

function parseSort(sort: string) {
  if (!sort) return null;
  if (sort.startsWith("-")) return { column: sort.slice(1), ascending: false };
  return { column: sort, ascending: true };
}

function mapRecord(record: any, fieldMap: Record<string, string>) {
  if (!record) return record;
  const reverseMap = Object.fromEntries(Object.entries(fieldMap).map(([k, v]) => [v, k]));
  const mapped: any = {};
  for (const [key, value] of Object.entries(record)) {
    mapped[reverseMap[key] || key] = value;
  }
  return mapped;
}

function mapInput(data: any, fieldMap: Record<string, string>) {
  if (!data) return data;
  const mapped: any = {};
  for (const [key, value] of Object.entries(data)) {
    mapped[fieldMap[key] || key] = value;
  }
  return mapped;
}

function createEntityWrapper(client: any, table: string, fieldMap: Record<string, string>) {
  const columns = SELECT_COLUMNS[table] || "*";

  return {
    async list(sort?: string, limit?: number): Promise<any[]> {
      let query = client.from(table).select(columns);
      const s = parseSort(sort || "");
      if (s) {
        const col = fieldMap[s.column] || s.column;
        query = query.order(col, { ascending: s.ascending });
      }
      if (limit) query = query.limit(limit);
      const { data, error } = await query;
      if (error) throw error;
      return (data || []).map((r: any) => mapRecord(r, fieldMap));
    },

    async filter(queryObj: any, sort?: string, limit?: number): Promise<any[]> {
      let query = client.from(table).select(columns);
      query = applyQuery(query, queryObj, fieldMap);
      const s = parseSort(sort || "");
      if (s) {
        const col = fieldMap[s.column] || s.column;
        query = query.order(col, { ascending: s.ascending });
      }
      if (limit) query = query.limit(limit);
      const { data, error } = await query;
      if (error) throw error;
      return (data || []).map((r: any) => mapRecord(r, fieldMap));
    },

    async get(id: string): Promise<any> {
      const { data, error } = await client.from(table).select(columns).eq("id", id).single();
      if (error) throw error;
      return mapRecord(data, fieldMap);
    },

    async create(data: any): Promise<any> {
      const input = mapInput(data, fieldMap);
      const { data: result, error } = await client.from(table).insert(input).select(columns).single();
      if (error) throw error;
      return mapRecord(result, fieldMap);
    },

    async bulkCreate(records: any[]): Promise<any[]> {
      const inputs = records.map((r) => mapInput(r, fieldMap));
      const { data, error } = await client.from(table).insert(inputs).select(columns);
      if (error) throw error;
      return (data || []).map((r: any) => mapRecord(r, fieldMap));
    },

    async update(id: string, data: any): Promise<any> {
      const input = mapInput(data, fieldMap);
      const { data: result, error } = await client.from(table).update(input).eq("id", id).select(columns).single();
      if (error) throw error;
      return mapRecord(result, fieldMap);
    },

    async updateMany(queryObj: any, updateObj: any): Promise<any[]> {
      const input = mapInput(updateObj.$set || updateObj, fieldMap);
      let query = client.from(table).update(input);
      query = applyQuery(query, queryObj, fieldMap);
      const { data, error } = await query.select(columns);
      if (error) throw error;
      return (data || []).map((r: any) => mapRecord(r, fieldMap));
    },

    async delete(id: string): Promise<boolean> {
      const { error } = await client.from(table).delete().eq("id", id);
      if (error) throw error;
      return true;
    },

    async deleteMany(queryObj: any): Promise<boolean> {
      let query = client.from(table).delete();
      query = applyQuery(query, queryObj, fieldMap);
      const { error } = await query;
      if (error) throw error;
      return true;
    },
  };
}

/// One wrapper per entity name, e.g. `entities.DailyCheckin.list(...)`.
/// Typed as a string-keyed record because the Proxy builds wrappers on demand
/// for any name, which is also how the Base44 SDK behaved.
export type EntityWrapper = ReturnType<typeof createEntityWrapper>;
export type Entities = Record<string, EntityWrapper>;

function createEntities(client: any): Entities {
  return new Proxy({} as Entities, {
    get(_, entityName: string) {
      const table = TABLE_MAP[entityName] || entityName.toLowerCase();
      const fieldMap = FIELD_MAPS[entityName] || {};
      return createEntityWrapper(client, table, fieldMap);
    },
  });
}

// ===== Auth =====

export async function getUserFromToken(token: string) {
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) return null;
  const { data: profile } = await client.from("profiles").select("*").eq("id", user.id).single();

  // Sync email to profiles table so backend functions can query user emails
  // without the Supabase Auth Admin API.
  if (user.email && profile?.email !== user.email.toLowerCase()) {
    await client.from("profiles").update({ email: user.email.toLowerCase() }).eq("id", user.id);
  }

  return {
    id: user.id,
    email: user.email,
    full_name: profile?.full_name || user.user_metadata?.full_name || "",
    role: profile?.role || "user",
    membership: profile?.membership || null,
    gender: profile?.gender || null,
    health_concerns: profile?.health_concerns || [],
    hasVidaPlus: profile?.membership === "vida_plus",
    reminder_enabled: profile?.reminder_enabled ?? true,
    reminder_time: profile?.reminder_time || "20:00",
    content_updates: profile?.content_updates ?? true,
    cycle_tracking_enabled: profile?.cycle_tracking_enabled ?? true,
    last_rewind_date: profile?.last_rewind_date || null,
  };
}

// ===== Main init function =====

export async function initSupabase(req: Request) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    // Body might already be consumed or empty
  }

  // The Authorization header is the real source of the caller's identity on a
  // Supabase Edge Function — Supabase already validates the JWT before the
  // function runs, and the header cannot be forged past that check.
  //
  // `body._supabaseToken` is the legacy path: the Base44 client proxy attached
  // the token to the request body because Base44's runtime did not forward the
  // header. It stays as a fallback so a browser still running the old bundle
  // keeps working through the transition, and should be deleted once the
  // frontend calls `supabase.functions.invoke` directly.
  const header = req.headers.get("Authorization") ?? "";
  const bearer = header.toLowerCase().startsWith("bearer ")
    ? header.slice(7).trim()
    : "";
  const token = bearer || body._supabaseToken;
  delete body._supabaseToken;

  if (!token) {
    return { body, user: null, entities: null, serviceEntities: createEntities(createServiceClient()) };
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const user = await getUserFromToken(token);

  return {
    body,
    user,
    entities: createEntities(userClient),
    serviceEntities: createEntities(createServiceClient()),
  };
}

export async function adminListUsers() {
  const serviceClient = createServiceClient();
  const { data: profiles, error } = await serviceClient.from("profiles").select("*");
  if (error) throw new Error(`Failed to load profiles: ${error.message}`);
  return (profiles || []).map((p: any) => ({
    id: p.id,
    email: p.email || "",
    full_name: p.full_name || "",
    role: p.role || "user",
    membership: p.membership || null,
    gender: p.gender || null,
    health_concerns: p.health_concerns || [],
    reminder_enabled: p.reminder_enabled ?? true,
    reminder_time: p.reminder_time || "20:00",
    content_updates: p.content_updates ?? true,
    content_updates_enabled: p.content_updates ?? true,
    cycle_tracking_enabled: p.cycle_tracking_enabled ?? true,
    last_rewind_date: p.last_rewind_date || null,
    last_reminder_date: p.last_reminder_date || null,
    reminder_timezone: p.reminder_timezone || "UTC",
  }));
}

export function initSupabaseService() {
  const serviceEntities = createEntities(createServiceClient());
  return { serviceEntities, db: { entities: serviceEntities } };
}

export async function adminGetUserIdByEmail(email: string): Promise<string | null> {
  const serviceClient = createServiceClient();
  const { data, error } = await serviceClient
    .from("profiles")
    .select("id")
    .eq("email", email.toLowerCase())
    .maybeSingle();
  if (error) {
    console.error("adminGetUserIdByEmail error:", error);
    return null;
  }
  return data?.id || null;
}

export function createServiceClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}