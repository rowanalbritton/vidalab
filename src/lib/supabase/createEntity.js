import { supabase } from "../supabaseClient";
import { applyQuery } from "./queryTranslator";

// Factory that creates an entity wrapper matching the Base44 SDK entity API.
// Mirrors: list, filter, get, create, bulkCreate, update, updateMany,
// bulkUpdate, delete, deleteMany, subscribe, schema.
//
// Options:
//   table         — Supabase table name (required)
//   userOwned     — if true, maps created_by_id <-> user_id transparently
//   selectColumns — explicit column list (needed when column-level grants
//                   hide certain columns, e.g. community tables)
//   fieldMap      — custom field name mapping { base44Name: supabaseName }
//                   applied in both directions (read maps back, write maps forward)
//   ownerColumn   — the table's owner column. Defaults to "user_id"; the
//                   community tables use "author_id" (see
//                   supabase/migrations/20260924140000_reconcile_community_schema.sql).
export function createEntity({ table, userOwned = false, selectColumns = null, fieldMap = {}, publicOnly = false, activeOnly = false, ownerColumn = "user_id" }) {
  // Merge userOwned mapping into fieldMap
  const fullFieldMap = userOwned
    ? { created_by_id: ownerColumn, ...fieldMap }
    : { ...fieldMap };

  // Reverse map for reading: { user_id: "created_by_id" }
  const reverseFieldMap = Object.fromEntries(
    Object.entries(fullFieldMap).map(([k, v]) => [v, k])
  );

  const columns = selectColumns || "*";

  function mapRecord(record) {
    if (!record) return record;
    const mapped = {};
    for (const [key, value] of Object.entries(record)) {
      const targetKey = reverseFieldMap[key] || key;
      mapped[targetKey] = value;
    }
    return mapped;
  }

  function mapInput(data) {
    if (!data) return data;
    const mapped = {};
    for (const [key, value] of Object.entries(data)) {
      const targetKey = fullFieldMap[key] || key;
      mapped[targetKey] = value;
    }
    return mapped;
  }

  function parseSort(sort) {
    if (!sort) return null;
    if (sort.startsWith("-")) return { column: sort.slice(1), ascending: false };
    return { column: sort, ascending: true };
  }

  async function list(sort, limit) {
    let query = supabase.from(table).select(columns);
    if (publicOnly) query = query.eq("is_public", true);
    if (activeOnly) query = query.eq("status", "active");
    const sortInfo = parseSort(sort);
    if (sortInfo) {
      const sortCol = fullFieldMap[sortInfo.column] || sortInfo.column;
      query = query.order(sortCol, { ascending: sortInfo.ascending });
    }
    if (limit) query = query.limit(limit);
    const { data, error } = await query;
    if (error) throw error;
    return (data || []).map(mapRecord);
  }

  async function filter(queryObj, sort, limit) {
    let query = supabase.from(table).select(columns);
    if (publicOnly) query = query.eq("is_public", true);
    if (activeOnly) query = query.eq("status", "active");
    query = applyQuery(query, queryObj, fullFieldMap);
    const sortInfo = parseSort(sort);
    if (sortInfo) {
      const sortCol = fullFieldMap[sortInfo.column] || sortInfo.column;
      query = query.order(sortCol, { ascending: sortInfo.ascending });
    }
    if (limit) query = query.limit(limit);
    const { data, error } = await query;
    if (error) throw error;
    return (data || []).map(mapRecord);
  }

  async function get(id) {
    const { data, error } = await supabase
      .from(table)
      .select(columns)
      .eq("id", id)
      .single();
    if (error) throw error;
    return mapRecord(data);
  }

  async function getCurrentUserId() {
    if (!userOwned) return null;
    const { data: { user } } = await supabase.auth.getUser();
    return user?.id || null;
  }

  async function create(data) {
    const input = mapInput(data);
    if (userOwned) {
      const uid = await getCurrentUserId();
      if (uid) input[ownerColumn] = uid;
    }
    const { data: result, error } = await supabase
      .from(table)
      .insert(input)
      .select(columns)
      .single();
    if (error) throw error;
    return mapRecord(result);
  }

  async function bulkCreate(records) {
    const inputs = records.map(mapInput);
    if (userOwned) {
      const uid = await getCurrentUserId();
      if (uid) inputs.forEach((r) => { if (!r[ownerColumn]) r[ownerColumn] = uid; });
    }
    const { data, error } = await supabase.from(table).insert(inputs).select(columns);
    if (error) throw error;
    return (data || []).map(mapRecord);
  }

  async function update(id, data) {
    const input = mapInput(data);
    const { data: result, error } = await supabase
      .from(table)
      .update(input)
      .eq("id", id)
      .select(columns)
      .single();
    if (error) throw error;
    return mapRecord(result);
  }

  async function updateMany(queryObj, updateObj) {
    const input = mapInput(updateObj.$set || updateObj);
    let query = supabase.from(table).update(input);
    query = applyQuery(query, queryObj, fullFieldMap);
    const { data, error } = await query.select(columns);
    if (error) throw error;
    return (data || []).map(mapRecord);
  }

  async function bulkUpdate(records) {
    const results = [];
    for (const record of records) {
      const { id, ...data } = record;
      results.push(await update(id, data));
    }
    return results;
  }

  async function deleteRecord(id) {
    const { error } = await supabase.from(table).delete().eq("id", id);
    if (error) throw error;
    return true;
  }

  async function deleteMany(queryObj) {
    let query = supabase.from(table).delete();
    query = applyQuery(query, queryObj, fullFieldMap);
    const { error } = await query;
    if (error) throw error;
    return true;
  }

  function subscribe(callback) {
    const channel = supabase
      .channel(`${table}-changes`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table },
        (payload) => {
          const typeMap = { INSERT: "create", UPDATE: "update", DELETE: "delete" };
          callback({
            id: payload.new?.id || payload.old?.id,
            type: typeMap[payload.eventType],
            data: mapRecord(payload.new || payload.old),
          });
        }
      )
      .subscribe();
    return () => supabase.removeChannel(channel);
  }

  async function schema() {
    return {};
  }

  return {
    list,
    filter,
    get,
    create,
    bulkCreate,
    update,
    updateMany,
    bulkUpdate,
    delete: deleteRecord,
    deleteMany,
    subscribe,
    schema,
  };
}