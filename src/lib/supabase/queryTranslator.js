// Translates Base44-style MongoDB query objects to Supabase PostgREST filter chains.

const OPERATOR_MAP = {
  $eq: "eq",
  $ne: "neq",
  $gt: "gt",
  $gte: "gte",
  $lt: "lt",
  $lte: "lte",
  $in: "in",
  $like: "like",
  $ilike: "ilike",
};

function applyCondition(query, field, condition, fieldMap) {
  const supaField = fieldMap[field] || field;

  if (condition === null || condition === undefined) {
    return query.is(supaField, null);
  }

  if (Array.isArray(condition)) {
    return query.in(supaField, condition);
  }

  if (typeof condition !== "object") {
    return query.eq(supaField, condition);
  }

  // Operator object like { $gte: 18, $lte: 65 }
  for (const [op, val] of Object.entries(condition)) {
    const method = OPERATOR_MAP[op];
    if (method) {
      query = query[method](supaField, val);
    } else if (op === "$nin") {
      query = query.not(supaField, "in", val);
    } else if (op === "$regex") {
      query = query.ilike(supaField, `%${val}%`);
    } else if (op === "$ne") {
      query = query.neq(supaField, val);
    }
  }
  return query;
}

function buildOrString(conditions, fieldMap) {
  return conditions
    .map((cond) => {
      const parts = [];
      for (const [field, value] of Object.entries(cond)) {
        const supaField = fieldMap[field] || field;
        if (value !== null && typeof value === "object" && !Array.isArray(value)) {
          for (const [op, val] of Object.entries(value)) {
            const method = OPERATOR_MAP[op] || "eq";
            parts.push(`${supaField}.${method}.${val}`);
          }
        } else {
          parts.push(`${supaField}.eq.${value}`);
        }
      }
      return parts.join(",");
    })
    .join(",");
}

export function applyQuery(query, queryObj, fieldMap = {}) {
  if (!queryObj || typeof queryObj !== "object") return query;

  for (const [key, value] of Object.entries(queryObj)) {
    if (key === "$or") {
      query = query.or(buildOrString(value, fieldMap));
    } else if (key === "$and") {
      for (const cond of value) {
        for (const [f, v] of Object.entries(cond)) {
          query = applyCondition(query, f, v, fieldMap);
        }
      }
    } else {
      query = applyCondition(query, key, value, fieldMap);
    }
  }

  return query;
}