// Shared check-in formatter used by Vida+ backend functions.
// Sorts oldest → newest and renders each check-in as a compact line
// the LLM can read chronologically.

export function formatCheckins(checkins: any[]): string {
  const sorted = [...checkins].sort((a, b) => {
    const da = new Date((a.checkin_date || "").slice(0, 10) + "T00:00:00").getTime();
    const db = new Date((b.checkin_date || "").slice(0, 10) + "T00:00:00").getTime();
    return da - db;
  });
  return sorted
    .map((c) => {
      const parts: string[] = [];
      parts.push(`Date: ${c.checkin_date}`);
      parts.push(`Energy: ${c.energy ?? "-"}/5`);
      if (c.sleep_hours != null) parts.push(`Sleep: ${c.sleep_hours}h (quality ${c.sleep_quality ?? "-"}/5)`);
      if (c.mood) parts.push(`Mood: ${c.mood}`);
      if (c.pain_level != null) parts.push(`Pain: ${c.pain_level}/3`);
      if (Array.isArray(c.symptoms) && c.symptoms.length && !c.symptoms.includes("none"))
        parts.push(`Symptoms: ${c.symptoms.join(", ")}`);
      if (c.notes) parts.push(`Notes: "${c.notes}"`);
      return parts.join(" | ");
    })
    .join("\n");
}